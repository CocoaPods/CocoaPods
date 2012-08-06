module Pod
  class Command
    class Linter
      include Config::Mixin

      # TODO: Add check to ensure that attributes inherited by subspecs are not duplicated ?

      attr_accessor :quick, :lenient, :no_clean
      attr_reader   :spec, :file
      attr_reader   :errors, :warnings, :notes

      def initialize(podspec)
        @file = podspec
      end

      def spec_name
        file.basename('.*').to_s
      end

      # Takes an array of podspec files and lints them all
      #
      # It returns true if the spec passed validation
      #
      def lint
        @errors, @warnings, @notes = [], [], []
        @platform_errors, @platform_warnings, @platform_notes = {}, {}, {}

        if !deprecation_errors.empty?
          @errors = deprecation_errors
        else
          @spec = Specification.from_file(file)
          platforms = spec.available_platforms
          platforms.each do |platform|
            @platform_errors[platform], @platform_warnings[platform], @platform_notes[platform] = [], [], []

            spec.activate_platform(platform)
            @platform = platform
            puts "\n\n#{spec} - Analyzing on #{platform} platform.".green.reversed if config.verbose? && !@quick

            # Skip validation if there are errors in the podspec as it would result in a crash
            if !podspec_errors.empty?
              @platform_errors[platform]   += podspec_errors
              @platform_notes[platform]    << "#{platform.name} [!] Fatal errors found skipping the rest of the validation"
            else
              @platform_warnings[platform] += podspec_warnings
              peform_extensive_analysis unless quick
            end
          end

          # Get common messages
          @errors   = @platform_errors.values.reduce(:&)
          @warnings = @platform_warnings.values.reduce(:&)
          @notes    = @platform_notes.values.reduce(:&)

          platforms.each do |platform|
            # Mark platform specific messages
            @errors   += (@platform_errors[platform] - @errors).map {|m| "[#{platform}] #{m}"}
            @warnings += (@platform_warnings[platform] - @warnings).map {|m| "[#{platform}] #{m}"}
            @notes    += (@platform_notes[platform] - @notes).map {|m| "[#{platform}] #{m}"}
          end
        end

        valid?
      end

      def valid?
        lenient ? errors.empty? : ( errors.empty? && warnings.empty? )
      end

      def result_type
        return :error   unless errors.empty?
        return :warning unless warnings.empty?
        return :note    unless notes.empty?
        :success
      end

      # Performs platform specific analysis.
      # It requires to download the source at each iteration
      #
      def peform_extensive_analysis
        set_up_lint_environment
        install_pod
        puts "Building with xcodebuild.\n".yellow if config.verbose?
        # treat xcodebuild warnings as notes because the spec maintainer might not be the author of the library
        xcodebuild_output.each { |msg| ( msg.include?('error: ') ? @platform_errors[@platform] : @platform_notes[@platform] ) << msg }
        @platform_errors[@platform]   += file_patterns_errors
        @platform_warnings[@platform] += file_patterns_warnings
        tear_down_lint_environment
      end

      def install_pod
        podfile = podfile_from_spec
        config.verbose
        installer = Installer.new(podfile)
        installer.install!
        @pod = installer.pods.find { |pod| pod.top_specification == spec }
        config.silent
      end

      def podfile_from_spec
        name     = spec.name
        podspec  = file.realpath.to_s
        platform = @platform
        podfile  = Pod::Podfile.new do
          platform(platform.to_sym, platform.deployment_target)
          pod name, :podspec => podspec
        end
        podfile
      end

      def set_up_lint_environment
        tmp_dir.rmtree if tmp_dir.exist?
        tmp_dir.mkpath
        @original_config = Config.instance.clone
        config.project_root      = tmp_dir
        config.project_pods_root = tmp_dir + 'Pods'
        config.silent            = !config.verbose
        config.integrate_targets = false
        config.generate_docs     = false
      end

      def tear_down_lint_environment
        tmp_dir.rmtree unless no_clean
        Config.instance = @original_config
      end

      def tmp_dir
        Pathname.new('/tmp/CocoaPods/Lint')
      end

      def pod_dir
        tmp_dir + 'Pods' + spec.name
      end

      # It reads a podspec file and checks for strings corresponding
      # to features that are or will be deprecated
      #
      # @return [Array<String>]
      #
      def deprecation_errors
        text = @file.read
        deprecations = []
        deprecations << "`config.ios?' and `config.osx?' are deprecated"              if text. =~ /config\..?os.?/
        deprecations << "clean_paths are deprecated and ignored (use preserve_paths)" if text. =~ /clean_paths/
        deprecations
      end

      # @return [Array<String>] List of the fatal defects detected in a podspec
      def podspec_errors
        messages = []
        messages << "The name of the spec should match the name of the file" unless names_match?
        messages << "Unrecognized platfrom" unless platform_valid?
        messages << "Missing name"          unless spec.name
        messages << "Missing version"       unless spec.version
        messages << "Missing summary"       unless spec.summary
        messages << "Missing homepage"      unless spec.homepage
        messages << "Missing author(s)"     unless spec.authors
        messages << "Missing or invalid source: #{spec.source}" unless source_valid?

        # attributes with multiplatform values
        return messages unless platform_valid?
        messages << "The spec appears to be empty (no source files, resources, or preserve paths)" if spec.source_files.empty? && spec.subspecs.empty? && spec.resources.empty? && spec.preserve_paths.empty?
        messages += paths_starting_with_a_slash_errors
        messages += deprecation_errors
        messages
      end

      def names_match?
        return true unless spec.name
        root_name = spec.name.match(/[^\/]*/)[0]
        file.basename.to_s == root_name + '.podspec'
      end

      def platform_valid?
        !spec.platform || [:ios, :osx].include?(spec.platform.name)
      end

      def source_valid?
        spec.source && !(spec.source =~ /http:\/\/EXAMPLE/)
      end

      def paths_starting_with_a_slash_errors
        messages = []
        %w[source_files public_header_files resources clean_paths].each do |accessor|
          patterns = spec.send(accessor.to_sym)
          # Some values are multiplaform
          patterns = patterns.is_a?(Hash) ? patterns.values.flatten(1) : patterns
          patterns = patterns.compact # some patterns may be nil (public_header_files, for instance)
          patterns.each do |pattern|
            # Skip FileList that would otherwise be resolved from the working directory resulting
            # in a potentially very expensi operation
            next if pattern.is_a?(FileList)
            invalid = pattern.is_a?(Array) ? pattern.any? { |path| path.start_with?('/') } : pattern.start_with?('/')
            if invalid
              messages << "Paths cannot start with a slash (#{accessor})"
              break
            end
          end
        end
        messages
      end

      # @return [Array<String>] List of the **non** fatal defects detected in a podspec
      def podspec_warnings
        license  = spec.license || {}
        source   = spec.source  || {}
        text     = @file.read
        messages = []
        messages << "Missing license type"                                unless license[:type]
        messages << "Sample license type"                                 if license[:type] && license[:type] =~ /\(example\)/
        messages << "Invalid license type"                                if license[:type] && license[:type] =~ /\n/
        messages << "The summary is not meaningful"                       if spec.summary =~ /A short description of/
        messages << "The description is not meaningful"                   if spec.description && spec.description =~ /An optional longer description of/
        messages << "The summary should end with a dot"                   if spec.summary !~ /.*\./
        messages << "The description should end with a dot"               if spec.description !~ /.*\./ && spec.description != spec.summary
        messages << "Git sources should specify either a tag or a commit" if source[:git] && !source[:commit] && !source[:tag]
        messages << "Github repositories should end in `.git'"            if github_source? && source[:git] !~ /.*\.git/
        messages << "Github repositories should use `https' link"         if github_source? && source[:git] !~ /https:\/\/github.com/
        messages << "Comments must be deleted"                            if text.scan(/^\s*#/).length > 24
        messages
      end

      def github_source?
        spec.source && spec.source[:git] =~ /github.com/
      end

      # It creates a podfile in memory and builds a library containing
      # the pod for all available platfroms with xcodebuild.
      #
      # @return [Array<String>]
      #
      def xcodebuild_output
        return [] if `which xcodebuild`.strip.empty?
        messages      = []
        output        = Dir.chdir(config.project_pods_root) { `xcodebuild clean build 2>&1` }
        clean_output  = process_xcode_build_output(output)
        messages     += clean_output
        puts(output) if config.verbose?
        messages
      end

      def process_xcode_build_output(output)
        output_by_line = output.split("\n")
        selected_lines = output_by_line.select do |l|
          l.include?('error: ') && (l !~ /errors? generated\./) && (l !~ /error: \(null\)/)\
            || l.include?('warning: ') && (l !~ /warnings? generated\./)\
            || l.include?('note: ') && (l !~ /expanded from macro/)
        end
        selected_lines.map do |l|
          new = l.gsub(/\/tmp\/CocoaPods\/Lint\/Pods\//,'') # Remove the unnecessary tmp path
          new.gsub!(/^ */,' ')                              # Remove indentation
          "XCODEBUILD > " << new                            # Mark
        end
      end

      # It checks that every file pattern specified in a spec yields
      # at least one file. It requires the pods to be alredy present
      # in the current working directory under Pods/spec.name.
      #
      # @return [Array<String>]
      #
      def file_patterns_errors
        messages = []
        messages << "The sources did not match any file"                     if !spec.source_files.empty? && @pod.source_files.empty?
        messages << "The resources did not match any file"                   if !spec.resources.empty? && @pod.resource_files.empty?
        messages << "The preserve_paths did not match any file"              if !spec.preserve_paths.empty? && @pod.preserve_files.empty?
        messages << "The exclude_header_search_paths did not match any file" if !spec.exclude_header_search_paths.empty? && @pod.headers_excluded_from_search_paths.empty?
        messages
      end

      def file_patterns_warnings
        messages = []
        unless @pod.license_file || spec.license && ( spec.license[:type] == 'Public Domain' || spec.license[:text] )
          messages << "Unable to find a license file"
        end
        messages
      end
    end
  end
end
