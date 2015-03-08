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
      @source_urls = source_urls.map { |url| SourcesManager.source_with_name_or_url(url) }.map(&:url)
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

    # @return [Bool] Whether frameworks should be used for the installation.
    #
    attr_accessor :use_frameworks

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
      else  :note
      end
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
      Pathname(Dir.tmpdir) + 'CocoaPods/Lint'
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
        validate_vendored_dynamic_frameworks
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
        warning('url', "There was a problem validating the URL #{url}.")
      elsif !resp.success?
        warning('url', "The URL (#{url}) is not reachable.")
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
          warning('screenshot', "The screenshot #{screenshot} is not a valid image.")
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
      deployment_target = spec.subspec_by_name(subspec_name).deployment_target(consumer.platform_name)
      podfile = podfile_from_spec(consumer.platform_name, deployment_target, use_frameworks)
      sandbox = Sandbox.new(config.sandbox_root)
      installer = Installer.new(sandbox, podfile)
      installer.install!

      file_accessors = installer.aggregate_targets.map do |target|
        if target.pod_targets.any?(&:uses_swift?) && consumer.platform_name == :ios &&
            (deployment_target.nil? || Version.new(deployment_target).major < 8)
          uses_xctest = target.spec_consumers.any? { |c| (c.frameworks + c.weak_frameworks).include? 'XCTest' }
          error('swift', 'Swift support uses dynamic frameworks and is therefore only supported on iOS > 8.') unless uses_xctest
        end

        target.pod_targets.map(&:file_accessors)
      end.flatten

      @file_accessor = file_accessors.find { |accessor| accessor.spec.root.name == spec.root.name }
      config.silent
    end

    def validate_vendored_dynamic_frameworks
      deployment_target = spec.subspec_by_name(subspec_name).deployment_target(consumer.platform_name)

      unless file_accessor.nil?
        dynamic_frameworks = file_accessor.vendored_frameworks.select { |fw| `file #{fw + fw.basename('.framework')} 2>&1` =~ /dynamically linked/ }
        dynamic_libraries = file_accessor.vendored_libraries.select { |lib| `file #{lib} 2>&1` =~ /dynamically linked/ }
        if (dynamic_frameworks.count > 0 || dynamic_libraries.count > 0) && consumer.platform_name == :ios &&
            (deployment_target.nil? || Version.new(deployment_target).major < 8)
          error('dynamic', 'Dynamic frameworks and libraries are only supported on iOS 8.0 and onwards.')
        end
      end
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
          output = Pod.chdir(config.sandbox_root) { xcodebuild }
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

            if message =~ /\S+:\d+:\d+: error:/
              error('xcodebuild', message)
            elsif message =~ /\S+:\d+:\d+: warning:/
              warning('xcodebuild', message)
            else
              note('xcodebuild', message)
            end
          end
        end
      end
    end

    FILE_PATTERNS = %i(source_files resources preserve_paths vendored_libraries
                       vendored_frameworks public_header_files preserve_paths
                       private_header_files resource_bundles).freeze

    # It checks that every file pattern specified in a spec yields
    # at least one file. It requires the pods to be already present
    # in the current working directory under Pods/spec.name.
    #
    # @return [void]
    #
    def check_file_patterns
      FILE_PATTERNS.each do |attr_name|
        if respond_to?("_validate_#{attr_name}", true)
          send("_validate_#{attr_name}")
        end

        if !file_accessor.spec_consumer.send(attr_name).empty? && file_accessor.send(attr_name).empty?
          error('file patterns', "The `#{attr_name}` pattern did not match any file.")
        end
      end

      if consumer.spec.root?
        unless file_accessor.license || spec.license && (spec.license[:type] == 'Public Domain' || spec.license[:text])
          warning('license', 'Unable to find a license file')
        end
      end
    end

    def _validate_private_header_files
      _validate_header_files(:private_header_files)
    end

    def _validate_public_header_files
      _validate_header_files(:public_header_files)
    end

    # Ensures that a list of header files only contains header files.
    #
    def _validate_header_files(attr_name)
      non_header_files = file_accessor.send(attr_name).
        select { |f| !Sandbox::FileAccessor::HEADER_EXTENSIONS.include?(f.extname) }.
        map { |f| f.relative_path_from file_accessor.root }
      unless non_header_files.empty?
        error(attr_name, "The pattern matches non-header files (#{non_header_files.join(', ')}).")
      end
    end

    #-------------------------------------------------------------------------#

    private

    # !@group Result Helpers

    def error(attribute_name, message)
      add_result(:error, attribute_name, message)
    end

    def warning(attribute_name, message)
      add_result(:warning, attribute_name, message)
    end

    def note(attribute_name, message)
      add_result(:note, attribute_name, message)
    end

    def add_result(type, attribute_name, message)
      result = results.find do |r|
        r.type == type && r.attribute_name && r.message == message
      end
      unless result
        result = Result.new(type, attribute_name, message)
        results << result
      end
      result.platforms << consumer.platform_name if consumer
      result.subspecs << subspec_name if subspec_name && !result.subspecs.include?(subspec_name)
    end

    # Specialized Result to support subspecs aggregation
    #
    class Result < Specification::Linter::Results::Result
      def initialize(type, attribute_name, message)
        super(type, attribute_name, message)
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

    # @param  [String] platform_name
    #         the name of the platform, which should be declared
    #         in the Podfile.
    #
    # @param  [String] deployment_target
    #         the deployment target, which should be declared in
    #         the Podfile.
    #
    # @param  [Bool] use_frameworks
    #         whether frameworks should be used for the installation
    #
    # @return [Podfile] a podfile that requires the specification on the
    #         current platform.
    #
    # @note   The generated podfile takes into account whether the linter is
    #         in local mode.
    #
    def podfile_from_spec(platform_name, deployment_target, use_frameworks = true)
      name     = subspec_name ? subspec_name : spec.name
      podspec  = file.realpath
      local    = local?
      urls     = source_urls
      podfile  = Pod::Podfile.new do
        urls.each { |u| source(u) }
        use_frameworks!(use_frameworks)
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
        l.include?('error: ') && (l !~ /errors? generated\./) && (l !~ /error: \(null\)/)  ||
          l.include?('warning: ') && (l !~ /warnings? generated\./) && (l !~ /frameworks only run on iOS 8/) ||
          l.include?('note: ') && (l !~ /expanded from macro/)
      end
      selected_lines.map do |l|
        new = l.gsub(%r{#{validation_dir}/Pods/}, '')
        new.gsub!(/^ */, ' ')
      end
    end

    # @return [String] Executes xcodebuild in the current working directory and
    #         returns its output (both STDOUT and STDERR).
    #
    def xcodebuild
      command = 'xcodebuild clean build -target Pods CODE_SIGN_IDENTITY=-'
      command << ' -sdk iphonesimulator' if consumer.platform_name == :ios
      output, status = _xcodebuild "#{command} 2>&1"

      unless status.success?
        message = 'Returned an unsuccessful exit code.'
        message += ' You can use `--verbose` for more information.' unless config.verbose?
        error('xcodebuild', message)
      end

      output
    end

    # Executes the given command in the current working directory.
    #
    # @return [(String, Status)] The output of the given command and its
    #         resulting status.
    #
    def _xcodebuild(command)
      UI.puts command if config.verbose
      output = `#{command}`
      [output, $?]
    end

    #-------------------------------------------------------------------------#
  end
end
