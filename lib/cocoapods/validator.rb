require 'active_support/core_ext/array'
require 'active_support/core_ext/string/inflections'

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

    # Initialize a new instance
    #
    # @param  [Specification, Pathname, String] spec_or_path
    #         the Specification or the path of the `podspec` file to lint.
    #
    # @param  [Array<String>] source_urls
    #         the Source URLs to use in creating a {Podfile}.
    #
    def initialize(spec_or_path, source_urls)
      @source_urls = source_urls.map { |url| config.sources_manager.source_with_name_or_url(url) }.map(&:url)
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
      @results = []

      # Replace default spec with a subspec if asked for
      a_spec = spec
      if spec && @only_subspec
        subspec_name = @only_subspec.start_with?(spec.root.name) ? @only_subspec : "#{spec.root.name}/#{@only_subspec}"
        a_spec = spec.subspec_by_name(subspec_name)
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
      UI.puts results_message
    end

    def results_message
      message = ''
      results.each do |result|
        if result.platforms == [:ios]
          platform_message = '[iOS] '
        elsif result.platforms == [:osx]
          platform_message = '[OSX] '
        elsif result.platforms == [:watchos]
          platform_message = '[watchOS] '
        elsif result.platforms == [:tvos]
          platform_message = '[tvOS] '
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
        message << "    - #{type.ljust(5)} | #{platform_message}#{subspecs_message}#{result.attribute_name}: #{result.message}\n"
      end
      message << "\n"
    end

    def failure_reason
      results_by_type = results.group_by(&:type)
      results_by_type.default = []
      return nil if validated?
      reasons = []
      if (size = results_by_type[:error].size) && size > 0
        reasons << "#{size} #{'error'.pluralize(size)}"
      end
      if !allow_warnings && (size = results_by_type[:warning].size) && size > 0
        reason = "#{size} #{'warning'.pluralize(size)}"
        pronoun = size == 1 ? 'it' : 'them'
        reason << " (but you can use `--allow-warnings` to ignore #{pronoun})" if reasons.empty?
        reasons << reason
      end
      if results.all?(&:public_only)
        reasons << 'all results apply only to public specs, but you can use ' \
                   '`--private` to ignore them if linting the specification for a private pod'
      end
      if dot_swift_version.nil?
        reasons.to_sentence + ".\n[!] The validator for Swift projects uses " \
          'Swift 3.0 by default, if you are using a different version of ' \
          'swift you can use a `.swift-version` file to set the version for ' \
          "your Pod. For example to use Swift 2.3, run: \n" \
          '    `echo "2.3" > .swift-version`'
      else
        reasons.to_sentence
      end
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

    # @return [Bool] whether the linter should fail as soon as the first build
    #         variant causes an error. Helpful for i.e. multi-platforms specs,
    #         specs with subspecs.
    #
    attr_accessor :fail_fast

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

    # @return [Boolean] Whether attributes that affect only public sources
    #         Bool be skipped.
    #
    attr_accessor :ignore_public_only_results

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

    # @return [Symbol] The type, which should been used to display the result.
    #         One of: `:error`, `:warning`, `:note`.
    #
    def result_type
      applicable_results = results
      applicable_results = applicable_results.reject(&:public_only?) if ignore_public_only_results
      types              = applicable_results.map(&:type).uniq
      if    types.include?(:error)   then :error
      elsif types.include?(:warning) then :warning
      else  :note
      end
    end

    # @return [Symbol] The color, which should been used to display the result.
    #         One of: `:green`, `:yellow`, `:red`.
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

    # @return [String] the SWIFT_VERSION to use for validation.
    #
    def swift_version
      @swift_version ||= dot_swift_version || '3.0'
    end

    # Set the SWIFT_VERSION that should be used to validate the pod.
    #
    attr_writer :swift_version

    # @return [String] the SWIFT_VERSION in the .swift-version file or nil.
    #
    def dot_swift_version
      return unless file
      swift_version_path = file.dirname + '.swift-version'
      return unless swift_version_path.exist?
      swift_version_path.read.strip
    end

    # @return [String] A string representing the Swift version used during linting
    #                  or nil, if Swift was not used.
    #
    def used_swift_version
      swift_version if @installer.pod_targets.any?(&:uses_swift?)
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

      valid = spec.available_platforms.send(fail_fast ? :all? : :each) do |platform|
        UI.message "\n\n#{spec} - Analyzing on #{platform} platform.".green.reversed
        @consumer = spec.consumer(platform)
        setup_validation_environment
        begin
          create_app_project
          download_pod
          check_file_patterns
          install_pod
          add_app_project_import
          validate_vendored_dynamic_frameworks
          build_pod
        ensure
          tear_down_validation_environment
        end
        validated?
      end
      return false if fail_fast && !valid
      perform_extensive_subspec_analysis(spec) unless @no_subspecs
    rescue => e
      message = e.to_s
      message << "\n" << e.backtrace.join("\n") << "\n" if config.verbose?
      error('unknown', "Encountered an unknown error (#{message}) during validation.")
      false
    end

    # Recursively perform the extensive analysis on all subspecs
    #
    def perform_extensive_subspec_analysis(spec)
      spec.subspecs.send(fail_fast ? :all? : :each) do |subspec|
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
        warning('url', "There was a problem validating the URL #{url}.", true)
      elsif !resp.success?
        warning('url', "The URL (#{url}) is not reachable.", true)
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
        response = validate_url(screenshot)
        if response && !(response.headers['content-type'] && response.headers['content-type'].first =~ /image\/.*/i)
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

    def setup_validation_environment
      validation_dir.rmtree if validation_dir.exist?
      validation_dir.mkpath
      @original_config = Config.instance.clone
      config.installation_root   = validation_dir
      config.silent              = !config.verbose
    end

    def tear_down_validation_environment
      validation_dir.rmtree unless no_clean
      Config.instance = @original_config
    end

    def deployment_target
      deployment_target = spec.subspec_by_name(subspec_name).deployment_target(consumer.platform_name)
      if consumer.platform_name == :ios && use_frameworks
        minimum = Version.new('8.0')
        deployment_target = [Version.new(deployment_target), minimum].max.to_s
      end
      deployment_target
    end

    def download_pod
      podfile = podfile_from_spec(consumer.platform_name, deployment_target, use_frameworks)
      sandbox = Sandbox.new(config.sandbox_root)
      @installer = Installer.new(sandbox, podfile)
      @installer.use_default_plugins = false
      %i(prepare resolve_dependencies download_dependencies).each { |m| @installer.send(m) }
      @file_accessor = @installer.pod_targets.flat_map(&:file_accessors).find { |fa| fa.spec.name == consumer.spec.name }
    end

    def create_app_project
      app_project = Xcodeproj::Project.new(validation_dir + 'App.xcodeproj')
      app_project.new_target(:application, 'App', consumer.platform_name, deployment_target)
      app_project.save
      app_project.recreate_user_schemes
      Xcodeproj::XCScheme.share_scheme(app_project.path, 'App')
    end

    def add_app_project_import
      app_project = Xcodeproj::Project.open(validation_dir + 'App.xcodeproj')
      pod_target = @installer.pod_targets.find { |pt| pt.pod_name == spec.root.name }

      source_file = write_app_import_source_file(pod_target)
      source_file_ref = app_project.new_group('App', 'App').new_file(source_file)
      app_target = app_project.targets.first
      app_target.add_file_references([source_file_ref])
      add_swift_version(app_target)
      add_xctest(app_target) if @installer.pod_targets.any? { |pt| pt.spec_consumers.any? { |c| c.frameworks.include?('XCTest') } }
      app_project.save
    end

    def add_swift_version(app_target)
      app_target.build_configurations.each do |configuration|
        configuration.build_settings['SWIFT_VERSION'] = swift_version
      end
    end

    def add_xctest(app_target)
      app_target.build_configurations.each do |configuration|
        search_paths = configuration.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= '$(inherited)'
        search_paths << ' "$(PLATFORM_DIR)/Developer/Library/Frameworks"'
      end
    end

    def write_app_import_source_file(pod_target)
      language = pod_target.uses_swift? ? :swift : :objc

      if language == :swift
        source_file = validation_dir.+('App/main.swift')
        source_file.parent.mkpath
        import_statement = use_frameworks && pod_target.should_build? ? "import #{pod_target.product_module_name}\n" : ''
        source_file.open('w') { |f| f << import_statement }
      else
        source_file = validation_dir.+('App/main.m')
        source_file.parent.mkpath
        import_statement = if use_frameworks && pod_target.should_build?
                             "@import #{pod_target.product_module_name};\n"
                           else
                             header_name = "#{pod_target.product_module_name}/#{pod_target.product_module_name}.h"
                             if pod_target.sandbox.public_headers.root.+(header_name).file?
                               "#import <#{header_name}>\n"
                             else
                               ''
                             end
        end
        source_file.open('w') do |f|
          f << "@import Foundation;\n"
          f << "@import UIKit;\n" if consumer.platform_name == :ios || consumer.platform_name == :tvos
          f << "@import Cocoa;\n" if consumer.platform_name == :osx
          f << "#{import_statement}int main() {}\n"
        end
      end
      source_file
    end

    # It creates a podfile in memory and builds a library containing the pod
    # for all available platforms with xcodebuild.
    #
    def install_pod
      %i(verify_no_duplicate_framework_and_library_names
         verify_no_static_framework_transitive_dependencies
         verify_framework_usage generate_pods_project integrate_user_project
         perform_post_install_actions).each { |m| @installer.send(m) }

      deployment_target = spec.subspec_by_name(subspec_name).deployment_target(consumer.platform_name)
      @installer.aggregate_targets.each do |target|
        target.pod_targets.each do |pod_target|
          next unless native_target = pod_target.native_target
          native_target.build_configuration_list.build_configurations.each do |build_configuration|
            (build_configuration.build_settings['OTHER_CFLAGS'] ||= '$(inherited)') << ' -Wincomplete-umbrella'
            build_configuration.build_settings['SWIFT_VERSION'] = swift_version if pod_target.uses_swift?
          end
        end
        if target.pod_targets.any?(&:uses_swift?) && consumer.platform_name == :ios &&
            (deployment_target.nil? || Version.new(deployment_target).major < 8)
          uses_xctest = target.spec_consumers.any? { |c| (c.frameworks + c.weak_frameworks).include? 'XCTest' }
          error('swift', 'Swift support uses dynamic frameworks and is therefore only supported on iOS > 8.') unless uses_xctest
        end
      end
      @installer.pods_project.save
    end

    def validate_vendored_dynamic_frameworks
      deployment_target = spec.subspec_by_name(subspec_name).deployment_target(consumer.platform_name)

      unless file_accessor.nil?
        dynamic_frameworks = file_accessor.vendored_dynamic_frameworks
        dynamic_libraries = file_accessor.vendored_dynamic_libraries
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
      if !xcodebuild_available?
        UI.warn "Skipping compilation with `xcodebuild' because it can't be found.\n".yellow
      else
        UI.message "\nBuilding with xcodebuild.\n".yellow do
          output = xcodebuild
          UI.puts output
          parsed_output = parse_xcodebuild_output(output)
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

    def xcodebuild_available?
      !Executable.which('xcodebuild').nil? && ENV['COCOAPODS_VALIDATOR_SKIP_XCODEBUILD'].nil?
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

      _validate_header_mappings_dir
      if consumer.spec.root?
        _validate_license
        _validate_module_map
      end
    end

    def _validate_private_header_files
      _validate_header_files(:private_header_files)
    end

    def _validate_public_header_files
      _validate_header_files(:public_header_files)
    end

    def _validate_license
      unless file_accessor.license || spec.license && (spec.license[:type] == 'Public Domain' || spec.license[:text])
        warning('license', 'Unable to find a license file')
      end
    end

    def _validate_module_map
      if spec.module_map
        unless file_accessor.module_map.exist?
          error('module_map', 'Unable to find the specified module map file.')
        end
        unless file_accessor.module_map.extname == '.modulemap'
          relative_path = file_accessor.module_map.relative_path_from file_accessor.root
          error('module_map', "Unexpected file extension for modulemap file (#{relative_path}).")
        end
      end
    end

    def _validate_resource_bundles
      file_accessor.resource_bundles.each do |bundle, resource_paths|
        next unless resource_paths.empty?
        error('file patterns', "The `resource_bundles` pattern for `#{bundle}` did not match any file.")
      end
    end

    # Ensures that a list of header files only contains header files.
    #
    def _validate_header_files(attr_name)
      header_files = file_accessor.send(attr_name)
      non_header_files = header_files.
        select { |f| !Sandbox::FileAccessor::HEADER_EXTENSIONS.include?(f.extname) }.
        map { |f| f.relative_path_from(file_accessor.root) }
      unless non_header_files.empty?
        error(attr_name, "The pattern matches non-header files (#{non_header_files.join(', ')}).")
      end
      non_source_files = header_files - file_accessor.source_files
      unless non_source_files.empty?
        error(attr_name, 'The pattern includes header files that are not listed ' \
          "in source_files (#{non_source_files.join(', ')}).")
      end
    end

    def _validate_header_mappings_dir
      return unless header_mappings_dir = file_accessor.spec_consumer.header_mappings_dir
      absolute_mappings_dir = file_accessor.root + header_mappings_dir
      unless absolute_mappings_dir.directory?
        error('header_mappings_dir', "The header_mappings_dir (`#{header_mappings_dir}`) is not a directory.")
      end
      non_mapped_headers = file_accessor.headers.
        reject { |h| h.to_path.start_with?(absolute_mappings_dir.to_path) }.
        map { |f| f.relative_path_from(file_accessor.root) }
      unless non_mapped_headers.empty?
        error('header_mappings_dir', "There are header files outside of the header_mappings_dir (#{non_mapped_headers.join(', ')}).")
      end
    end

    #-------------------------------------------------------------------------#

    private

    # !@group Result Helpers

    def error(*args)
      add_result(:error, *args)
    end

    def warning(*args)
      add_result(:warning, *args)
    end

    def note(*args)
      add_result(:note, *args)
    end

    def add_result(type, attribute_name, message, public_only = false)
      result = results.find do |r|
        r.type == type && r.attribute_name && r.message == message && r.public_only? == public_only
      end
      unless result
        result = Result.new(type, attribute_name, message, public_only)
        results << result
      end
      result.platforms << consumer.platform_name if consumer
      result.subspecs << subspec_name if subspec_name && !result.subspecs.include?(subspec_name)
    end

    # Specialized Result to support subspecs aggregation
    #
    class Result < Specification::Linter::Results::Result
      def initialize(type, attribute_name, message, public_only = false)
        super(type, attribute_name, message, public_only)
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
      name     = subspec_name || spec.name
      podspec  = file.realpath
      local    = local?
      urls     = source_urls
      Pod::Podfile.new do
        install! 'cocoapods', :deterministic_uuids => false
        urls.each { |u| source(u) }
        target 'App' do
          use_frameworks!(use_frameworks)
          platform(platform_name, deployment_target)
          if local
            pod name, :path => podspec.dirname.to_s
          else
            pod name, :podspec => podspec.to_s
          end
        end
      end
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
        l.include?('error: ') && (l !~ /errors? generated\./) && (l !~ /error: \(null\)/) ||
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
      require 'fourflusher'
      command = ['clean', 'build', '-workspace', File.join(validation_dir, 'App.xcworkspace'), '-scheme', 'App', '-configuration', 'Release']
      case consumer.platform_name
      when :osx, :macos
        command += %w(CODE_SIGN_IDENTITY=)
      when :ios
        command += %w(CODE_SIGN_IDENTITY=- -sdk iphonesimulator)
        command += Fourflusher::SimControl.new.destination(:oldest, 'iOS', deployment_target)
      when :watchos
        command += %w(CODE_SIGN_IDENTITY=- -sdk watchsimulator)
        command += Fourflusher::SimControl.new.destination(:oldest, 'watchOS', deployment_target)
      when :tvos
        command += %w(CODE_SIGN_IDENTITY=- -sdk appletvsimulator)
        command += Fourflusher::SimControl.new.destination(:oldest, 'tvOS', deployment_target)
      end

      output, status = _xcodebuild(command)

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
      UI.puts 'xcodebuild ' << command.join(' ') if config.verbose
      Executable.capture_command('xcodebuild', command, :capture => :merge)
    end

    #-------------------------------------------------------------------------#
  end
end
