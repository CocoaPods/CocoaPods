module Pod
  # Validates a Specification.
  #
  # Extends the Linter from the Core to add additional which require the
  # LocalPod and the Installer.
  #
  # In detail it checks that the file patterns defined by the user match
  # actually do match at least a file and that the Pod builds, by installing
  # it without integration and building the project with xcodebuild.
  #
  class Validator
    include Config::Mixin

    # @return [Specification::Linter] the linter instance from CocoaPods
    #         Core.
    #
    attr_reader :linter

    # @param  [Specification, Pathname, String] spec_or_path
    #         the Specification or the path of the `podspec` file to lint.
    #
    # @param  [Array<String>] source_urls
    #         the Source URLs to use in creating a {Podfile}.
    #
    def initialize(spec_or_path, source_urls)
      @source_urls = source_urls
      @linter = Specification::Linter.new(spec_or_path)
    end

    #-------------------------------------------------------------------------#

    # @return [Specification] the specification to lint.
    #
    def spec
      @linter.spec
    end

    # @return [Pathname] the path of the `podspec` file where {#spec} is
    #         defined.
    #
    def file
      @linter.file
    end

    # @return [Sandbox::FileAccessor] the file accessor for the spec.
    #
    attr_accessor :file_accessor

    #-------------------------------------------------------------------------#

    # Lints the specification adding a {Result} for any
    # failed check to the {#results} list.
    #
    # @note   This method shows immediately which pod is being processed and
    #         overrides the printed line once the result is known.
    #
    # @return [Bool] whether the specification passed validation.
    #
    def validate
      @results  = []

      # Replace default spec with a subspec if asked for
      a_spec = spec
      if spec && @only_subspec
        a_spec = spec.subspec_by_name(@only_subspec)
        @subspec_name = a_spec.name
      end

      UI.print " -> #{a_spec ? a_spec.name : file.basename}\r" unless config.silent?
      $stdout.flush

      perform_linting
      perform_extensive_analysis(a_spec) if a_spec && !quick

      UI.puts ' -> '.send(result_color) << (a_spec ? a_spec.to_s : file.basename.to_s)
      print_results
      validated?
    end

    # Prints the result of the validation to the user.
    #
    # @return [void]
    #
    def print_results
      results.each do |result|
        if result.platforms == [:ios]
          platform_message = '[iOS] '
        elsif result.platforms == [:osx]
          platform_message = '[OSX] '
        end

        subspecs_message = ''
        if result.is_a?(Result)
          subspecs = result.subspecs.uniq
          if subspecs.count > 2
            subspecs_message = '[' + subspecs[0..2].join(', ') + ', and more...] '
          elsif subspecs.count > 0
            subspecs_message = '[' + subspecs.join(',') + '] '
          end
        end

        case result.type
        when :error   then type = 'ERROR'
        when :warning then type = 'WARN'
        when :note    then type = 'NOTE'
        else raise "#{result.type}" end
        UI.puts "    - #{type.ljust(5)} | #{platform_message}#{subspecs_message}#{result.message}"
      end
      UI.puts
    end

    #-------------------------------------------------------------------------#

    #  @!group Configuration

    # @return [Bool] whether the validation should skip the checks that
    #         requires the download of the library.
    #
    attr_accessor :quick

    # @return [Bool] whether the linter should not clean up temporary files
    #         for inspection.
    #
    attr_accessor :no_clean

    # @return [Bool] whether the validation should be performed against the root of
    #         the podspec instead to its original source.
    #
    # @note   Uses the `:path` option of the Podfile.
    #
    attr_accessor :local
    alias_method :local?, :local

    # @return [Bool] Whether the validator should fail on warnings, or only on errors.
    #
    attr_accessor :allow_warnings

    # @return [String] name of the subspec to check, if nil all subspecs are checked.
    #
    attr_accessor :only_subspec

    # @return [Bool] Whether the validator should validate all subspecs
    #
    attr_accessor :no_subspecs

    #-------------------------------------------------------------------------#

    # !@group Lint results

    #
    #
    attr_reader :results

    # @return [Boolean]
    #
    def validated?
      result_type != :error && (result_type != :warning || allow_warnings)
    end

    # @return [Symbol]
    #
    def result_type
      types = results.map(&:type).uniq
      if    types.include?(:error)   then :error
      elsif types.include?(:warning) then :warning
      else  :note end
    end

    # @return [Symbol]
    #
    def result_color
      case result_type
      when :error   then :red
      when :warning then :yellow
      else :green end
    end

    # @return [Pathname] the temporary directory used by the linter.
    #
    def validation_dir
      Pathname.new(File.join(Pathname.new('/tmp').realpath, 'CocoaPods/Lint'))
    end

    #-------------------------------------------------------------------------#

    private

    # !@group Lint steps

    #
    #
    def perform_linting
      linter.lint
      @results.concat(linter.results.to_a)
    end

    # Perform analysis for a given spec (or subspec)
    #
    def perform_extensive_analysis(spec)
      validate_homepage(spec)
      validate_screenshots(spec)
      validate_social_media_url(spec)
      validate_documentation_url(spec)
      validate_docset_url(spec)

      spec.available_platforms.each do |platform|
        UI.message "\n\n#{spec} - Analyzing on #{platform} platform.".green.reversed
        @consumer = spec.consumer(platform)
        setup_validation_environment
        install_pod
        build_pod
        check_file_patterns
        tear_down_validation_environment
      end
      perform_extensive_subspec_analysis(spec) unless @no_subspecs
    end

    # Recursively perform the extensive analysis on all subspecs
    #
    def perform_extensive_subspec_analysis(spec)
      spec.subspecs.each do |subspec|
        @subspec_name = subspec.name
        perform_extensive_analysis(subspec)
      end
    end

    attr_accessor :consumer
    attr_accessor :subspec_name

    # Performs validation of a URL
    #
    def validate_url(url)
      resp = Pod::HTTP.validate_url(url)

      if !resp
        warning "There was a problem validating the URL #{url}."
      elsif !resp.success?
        warning "The URL (#{url}) is not reachable."
      end

      resp
    end

    # Performs validations related to the `homepage` attribute.
    #
    def validate_homepage(spec)
      if spec.homepage
        validate_url(spec.homepage)
      end
    end

    # Performs validation related to the `screenshots` attribute.
    #
    def validate_screenshots(spec)
      spec.screenshots.compact.each do |screenshot|
        request = validate_url(screenshot)
        if request && !(request.headers['content-type'] && request.headers['content-type'].first =~ /image\/.*/i)
          warning "The screenshot #{screenshot} is not a valid image."
        end
      end
    end

    # Performs validations related to the `social_media_url` attribute.
    #
    def validate_social_media_url(spec)
      validate_url(spec.social_media_url) if spec.social_media_url
    end

    # Performs validations related to the `documentation_url` attribute.
    #
    def validate_documentation_url(spec)
      validate_url(spec.documentation_url) if spec.documentation_url
    end

    # Performs validations related to the `docset_url` attribute.
    #
    def validate_docset_url(spec)
      validate_url(spec.docset_url) if spec.docset_url
    end

    def setup_validation_environment
      validation_dir.rmtree if validation_dir.exist?
      validation_dir.mkpath
      @original_config = Config.instance.clone
      config.installation_root = validation_dir
      config.sandbox_root      = validation_dir + 'Pods'
      config.silent            = !config.verbose
      config.integrate_targets = false
      config.skip_repo_update  = true
    end

    def tear_down_validation_environment
      validation_dir.rmtree unless no_clean
      Config.instance = @original_config
    end

    # It creates a podfile in memory and builds a library containing the pod
    # for all available platforms with xcodebuild.
    #
    def install_pod
      podfile = podfile_from_spec(consumer.platform_name, spec.deployment_target(consumer.platform_name))
      sandbox = Sandbox.new(config.sandbox_root)
      installer = Installer.new(sandbox, podfile)
      installer.install!

      file_accessors = installer.aggregate_targets.map do |target|
        target.pod_targets.map(&:file_accessors)
      end.flatten

      @file_accessor = file_accessors.find { |accessor| accessor.spec.root.name == spec.root.name }
      config.silent
    end

    # Performs platform specific analysis. It requires to download the source
    # at each iteration
    #
    # @note   Xcode warnings are treaded as notes because the spec maintainer
    #         might not be the author of the library
    #
    # @return [void]
    #
    def build_pod
      if `which xcodebuild`.strip.empty?
        UI.warn "Skipping compilation with `xcodebuild' because it can't be found.\n".yellow
      else
        UI.message "\nBuilding with xcodebuild.\n".yellow do
          output = Dir.chdir(config.sandbox_root) { xcodebuild }
          UI.puts output
          parsed_output  = parse_xcodebuild_output(output)
          parsed_output.each do |message|
            # Checking the error for `InputFile` is to work around an Xcode
            # issue where linting would fail even though `xcodebuild` actually
            # succeeds. Xcode.app also doesn't fail when this issue occurs, so
            # it's safe for us to do the same.
            #
            # For more details see https://github.com/CocoaPods/CocoaPods/issues/2394#issuecomment-56658587
            #
            if message.include?("'InputFile' should have")
              next
            end

            if message.include?('error: ')
              error "[xcodebuild] #{message}"
            else
              note "[xcodebuild] #{message}"
            end
          end
        end
      end
    end

    # It checks that every file pattern specified in a spec yields
    # at least one file. It requires the pods to be already present
    # in the current working directory under Pods/spec.name.
    #
    # @return [void]
    #
    def check_file_patterns
      [:source_files, :resources, :preserve_paths, :vendored_libraries, :vendored_frameworks].each do |attr_name|
        # file_attr = Specification::DSL.attributes.values.find{|attr| attr.name == attr_name }
        if !file_accessor.spec_consumer.send(attr_name).empty? && file_accessor.send(attr_name).empty?
          error "The `#{attr_name}` pattern did not match any file."
        end
      end

      if consumer.spec.root?
        unless file_accessor.license || spec.license && (spec.license[:type] == 'Public Domain' || spec.license[:text])
          warning 'Unable to find a license file'
        end
      end
    end

    #-------------------------------------------------------------------------#

    private

    # !@group Result Helpers

    def error(message)
      add_result(:error, message)
    end

    def warning(message)
      add_result(:warning, message)
    end

    def note(message)
      add_result(:note, message)
    end

    def add_result(type, message)
      result = results.find { |r| r.type == type && r.message == message }
      unless result
        result = Result.new(type, message)
        results << result
      end
      result.platforms << consumer.platform_name if consumer
      result.subspecs << subspec_name if subspec_name && !result.subspecs.include?(subspec_name)
    end

    # Specialized Result to support subspecs aggregation
    #
    class Result < Specification::Linter::Results::Result
      def initialize(type, message)
        super(type, message)
        @subspecs = []
      end

      attr_reader :subspecs
    end

    #-------------------------------------------------------------------------#

    private

    # !@group Helpers

    # @return [Array<String>] an array of source URLs used to create the
    #         {Podfile} used in the linting process
    #
    attr_reader :source_urls

    # @return [Podfile] a podfile that requires the specification on the
    # current platform.
    #
    # @note   The generated podfile takes into account whether the linter is
    #         in local mode.
    #
    def podfile_from_spec(platform_name, deployment_target)
      name     = subspec_name ? subspec_name : spec.name
      podspec  = file.realpath
      local    = local?
      urls     = source_urls
      podfile  = Pod::Podfile.new do
        urls.each { |u| source(u) }
        platform(platform_name, deployment_target)
        if local
          pod name, :path => podspec.dirname.to_s
        else
          pod name, :podspec => podspec.to_s
        end
      end
      podfile
    end

    # Parse the xcode build output to identify the lines which are relevant
    # to the linter.
    #
    # @param  [String] output the output generated by the xcodebuild tool.
    #
    # @note   The indentation and the temporary path is stripped form the
    #         lines.
    #
    # @return [Array<String>] the lines that are relevant to the linter.
    #
    def parse_xcodebuild_output(output)
      lines = output.split("\n")
      selected_lines = lines.select do |l|
        l.include?('error: ') &&
          (l !~ /errors? generated\./) && (l !~ /error: \(null\)/)  ||
          l.include?('warning: ') && (l !~ /warnings? generated\./) ||
          l.include?('note: ') && (l !~ /expanded from macro/)
      end
      selected_lines.map do |l|
        new = l.gsub(/\/tmp\/CocoaPods\/Lint\/Pods\//, '')
        new.gsub!(/^ */, ' ')
      end
    end

    # @return [String] Executes xcodebuild in the current working directory and
    #         returns its output (both STDOUT and STDERR).
    #
    def xcodebuild
      UI.puts 'xcodebuild clean build -target Pods' if config.verbose?
      `xcodebuild clean build -target Pods 2>&1`
    end

    #-------------------------------------------------------------------------#
  end
end
