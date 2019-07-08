require 'cocoapods-core/source'
require 'rest'
require 'concurrent'

module Pod
  # Subclass of Pod::Source to provide support for CDN-based Specs repositories
  #
  class CDNSource < Source
    MAX_CDN_NETWORK_THREADS = 50
    MAX_NUMBER_OF_RETRIES = 5

    # @param [String] repo The name of the repository
    #
    def initialize(repo)
      @check_existing_files_for_update = false
      # Optimization: we initialize startup_time when the source is first initialized
      # and then test file modification dates against it. Any file that was touched
      # after the source was initialized, is considered fresh enough.
      @startup_time = Time.new

      @executor = Concurrent::ThreadPoolExecutor.new(
        :min_threads => 5,
        :max_threads => (ENV['MAX_CDN_NETWORK_THREADS'] || MAX_CDN_NETWORK_THREADS).to_i,
        :max_queue => 0 # unbounded work queue
      )

      @version_arrays_by_fragment_by_name = {}

      super(repo)
    end

    # @return [String] The URL of the source.
    #
    def url
      @url ||= File.read(repo.join('.url')).chomp.chomp('/') + '/'
    end

    # @return [String] The type of the source.
    #
    def type
      'CDN'
    end

    def refresh_metadata
      if metadata.nil?
        unless repo.exist?
          debug "CDN: Repo #{name} does not exist!"
          return
        end

        specs_dir.mkpath
        download_file('CocoaPods-version.yml')
      end

      super
    end

    def preheat_existing_files
      all_existing_files = [repo.join('**/*.yml'), repo.join('**/*.txt'), repo.join('**/*.json')].map(&Pathname.method(:glob)).flatten
      loaders = all_existing_files.map { |f| f.relative_path_from(repo).to_s }.map do |file|
        Concurrent::Promises.future_on(@executor) do
          download_file(file)
        end
      end

      catching_concurrent_errors do
        Concurrent::Promises.zip(*loaders).wait!
      end
    end

    # @return [Pathname] The directory where the specs are stored.
    #
    def specs_dir
      @specs_dir ||= repo + 'Specs'
    end

    # @!group Querying the source
    #-------------------------------------------------------------------------#

    # @return [Array<String>] the list of the name of all the Pods.
    #
    def pods
      download_file('all_pods.txt')
      local_file('all_pods.txt', &:to_a).map(&:chomp)
    end

    # @return [Array<Version>] all the available versions for the Pod, sorted
    #         from highest to lowest.
    #
    # @param  [String] name
    #         the name of the Pod.
    #
    def versions(name)
      return nil unless specs_dir
      raise ArgumentError, 'No name' unless name

      fragment = pod_shard_fragment(name)

      ensure_versions_file_loaded(fragment)

      return @versions_by_name[name] unless @versions_by_name[name].nil?

      pod_path_actual = pod_path(name)
      pod_path_relative = relative_pod_path(name)

      return nil if @version_arrays_by_fragment_by_name[fragment][name].nil?

      loaders = []
      @versions_by_name[name] ||= @version_arrays_by_fragment_by_name[fragment][name].map do |version|
        # Optimization: ensure all the podspec files at least exist. The correct one will get refreshed
        # in #specification_path regardless.
        podspec_version_path_relative = Pathname.new(version).join("#{name}.podspec.json")
        unless pod_path_actual.join(podspec_version_path_relative).exist?
          loaders << Concurrent::Promises.future_on(@executor) do
            download_file(pod_path_relative.join(podspec_version_path_relative).to_s)
          end
        end
        begin
          Version.new(version) if version[0, 1] != '.'
        rescue ArgumentError
          raise Informative, 'An unexpected version directory ' \
          "`#{version}` was encountered for the " \
          "`#{pod_path_actual}` Pod in the `#{name}` repository."
        end
      end.compact.sort.reverse

      catching_concurrent_errors do
        Concurrent::Promises.zip(*loaders).wait!
      end

      @versions_by_name[name]
    end

    # Returns the path of the specification with the given name and version.
    #
    # @param  [String] name
    #         the name of the Pod.
    #
    # @param  [Version,String] version
    #         the version for the specification.
    #
    # @return [Pathname] The path of the specification.
    #
    def specification_path(name, version)
      raise ArgumentError, 'No name' unless name
      raise ArgumentError, 'No version' unless version

      podspec_version_path_relative = Pathname.new(version.to_s).join("#{name}.podspec.json")
      relative_podspec = relative_pod_path(name).join(podspec_version_path_relative).to_s
      download_file(relative_podspec)
      pod_path(name).join(podspec_version_path_relative)
    end

    # @return [Array<Specification>] all the specifications contained by the
    #         source.
    #
    def all_specs
      raise Informative, "Can't retrieve all the specs for a CDN-backed source, it will take forever"
    end

    # @return [Array<Sets>] the sets of all the Pods.
    #
    def pod_sets
      raise Informative, "Can't retrieve all the pod sets for a CDN-backed source, it will take forever"
    end

    # @!group Searching the source
    #-------------------------------------------------------------------------#

    # @return [Set] a set for a given dependency. The set is identified by the
    #               name of the dependency and takes into account subspecs.
    #
    # @note   This method is optimized for fast lookups by name, i.e. it does
    #         *not* require iterating through {#pod_sets}
    #
    # @todo   Rename to #load_set
    #
    def search(query)
      unless specs_dir
        raise Informative, "Unable to find a source named: `#{name}`"
      end
      if query.is_a?(Dependency)
        query = query.root_name
      end

      fragment = pod_shard_fragment(query)

      ensure_versions_file_loaded(fragment)

      version_arrays_by_name = @version_arrays_by_fragment_by_name[fragment] || {}

      found = version_arrays_by_name[query].nil? ? nil : query

      if found
        set = set(query)
        set if set.specification_name == query
      end
    end

    # @return [Array<Set>] The list of the sets that contain the search term.
    #
    # @param  [String] query
    #         the search term. Can be a regular expression.
    #
    # @param  [Bool] full_text_search
    #         not supported due to performance reasons
    #
    # @note   full text search requires to load the specification for each pod,
    #         and therefore not supported.
    #
    def search_by_name(query, full_text_search = false)
      if full_text_search
        raise Informative, "Can't perform full text search, it will take forever"
      else
        super(query)
      end
    end

    # Check update dates for all existing files.
    # Does not download non-existing specs, since CDN-backed repo is updated live.
    #
    # @param  [Bool] show_output
    #
    # @return  [Array<String>] Always returns empty array, as it cannot know
    #          everything that actually changed.
    #
    def update(_show_output)
      @check_existing_files_for_update = true
      begin
        preheat_existing_files
      ensure
        @check_existing_files_for_update = false
      end
      []
    end

    def git?
      # Long story here. This property is actually used solely by Source::Manager to determine
      # which sources are updatable. Ideally, this would require a name change but @segiddins
      # has pointed out that it is public and could break plugins.
      # In any case, CDN-backed repos can be updated and therefore the value ought to be true.
      true
    end

    private

    def ensure_versions_file_loaded(fragment)
      return if !@version_arrays_by_fragment_by_name[fragment].nil? && !@check_existing_files_for_update

      # Index file that contains all the versions for all the pods in the shard.
      # We use those because you can't get a directory listing from a CDN.
      index_file_name = index_file_name_for_fragment(fragment)
      download_file(index_file_name)
      versions_raw = local_file(index_file_name, &:to_a).map(&:chomp)
      @version_arrays_by_fragment_by_name[fragment] = versions_raw.reduce({}) do |hash, row|
        row = row.split('/')
        pod = row.shift
        versions = row

        hash[pod] = versions
        hash
      end
    end

    def index_file_name_for_fragment(fragment)
      fragment_joined = fragment.join('_')
      fragment_joined = '_' + fragment_joined unless fragment.empty?
      "all_pods_versions#{fragment_joined}.txt"
    end

    def pod_shard_fragment(pod_name)
      metadata.path_fragment(pod_name)[0..-2]
    end

    def local_file(partial_url)
      file_path = repo.join(partial_url)
      File.open(file_path) do |file|
        yield file if block_given?
      end
    end

    def relative_pod_path(pod_name)
      pod_path(pod_name).relative_path_from(repo)
    end

    def download_file(partial_url)
      file_remote_url = URI.encode(url + partial_url.to_s)
      path = repo + partial_url

      if File.exist?(path)
        if @startup_time < File.mtime(path)
          debug "CDN: #{name} Relative path: #{partial_url} modified during this run! Returning local"
          return partial_url
        end

        unless @check_existing_files_for_update
          debug "CDN: #{name} Relative path: #{partial_url} exists! Returning local because checking is only perfomed in repo update"
          return partial_url
        end
      end

      path.dirname.mkpath

      etag_path = path.sub_ext(path.extname + '.etag')

      etag = File.read(etag_path) if File.exist?(etag_path)
      debug "CDN: #{name} Relative path: #{partial_url}, has ETag? #{etag}" unless etag.nil?

      download_from_url(partial_url, file_remote_url, etag)
    end

    def download_from_url(partial_url, file_remote_url, etag)
      path = repo + partial_url
      etag_path = path.sub_ext(path.extname + '.etag')

      response = download_retrying_connection_errors(partial_url, file_remote_url, etag)

      case response.status_code
      when 301
        redirect_location = response.headers['location'].first
        debug "CDN: #{name} Redirecting from #{file_remote_url} to #{redirect_location}"
        download_from_url(partial_url, redirect_location, etag)
      when 304
        debug "CDN: #{name} Relative path not modified: #{partial_url}"
        # We need to update the file modification date, as it is later used for freshness
        # optimization. See #initialize for more information.
        FileUtils.touch path
        partial_url
      when 200
        File.open(path, 'w') { |f| f.write(response.body) }

        etag_new = response.headers['etag'].first if response.headers.include?('etag')
        debug "CDN: #{name} Relative path downloaded: #{partial_url}, save ETag: #{etag_new}"
        File.open(etag_path, 'w') { |f| f.write(etag_new) } unless etag_new.nil?
        partial_url
      when 404
        debug "CDN: #{name} Relative path couldn't be downloaded: #{partial_url} Response: #{response.status_code}"
        nil
      else
        raise Informative, "CDN: #{name} URL couldn't be downloaded: #{file_remote_url} Response: #{response.status_code}"
      end
    end

    def download_retrying_connection_errors(partial_url, file_remote_url, etag, retries = MAX_NUMBER_OF_RETRIES)
      etag.nil? ? REST.get(file_remote_url) : REST.get(file_remote_url, 'If-None-Match' => etag)
    rescue REST::Error => e
      if retries <= 0
        raise Informative, "CDN: #{name} URL couldn't be downloaded: #{file_remote_url}, error: #{e}"
      else
        debug "CDN: #{name} Relative path: #{partial_url} error: #{e} - retrying"
        download_retrying_connection_errors(partial_url, file_remote_url, etag, retries - 1)
      end
    end

    def debug(message)
      if defined?(Pod::UI)
        Pod::UI.message(message)
      else
        CoreUI.puts(message)
      end
    end

    def catching_concurrent_errors
      yield
    rescue Concurrent::MultipleErrors => e
      errors = e.errors
      raise Informative, "CDN: #{name} Repo update failed - #{e.errors.size} error(s):\n#{errors.join("\n")}"
    end
  end
end
