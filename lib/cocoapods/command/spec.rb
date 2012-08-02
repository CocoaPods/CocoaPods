# encoding: utf-8

module Pod
  class Command
    class Spec < Command
      def self.banner
        %{Managing PodSpec files:

    $ pod spec create [ NAME | https://github.com/USER/REPO ]

      Creates a PodSpec, in the current working dir, called `NAME.podspec'.
      If a GitHub url is passed the spec is prepopulated.

    $ pod spec lint [ NAME.podspec | DIRECTORY | http://PATH/NAME.podspec ]

      Validates `NAME.podspec'. If a directory is provided it performs a quick
      validation on all the podspec files found, including subfolders. In case
      the argument is omitted, it defaults to the current working dir.
      }
      end

      def self.options
        [ ["--quick",       "Lint skips checks that would require to download and build the spec"],
          ["--only-errors", "Lint validates even if warnings are present"],
          ["--no-clean",    "Lint leaves the build directory intact for inspection"] ].concat(super)
      end

      def initialize(argv)
        @action = argv.shift_argument
        if @action == 'create'
          @name_or_url     = argv.shift_argument
          @url             = argv.shift_argument
          super if @name_or_url.nil?
        elsif @action == 'lint'
          @quick           = argv.option('--quick')
          @only_errors     = argv.option('--only-errors')
          @no_clean        = argv.option('--no-clean')
          @repo_or_podspec = argv.shift_argument unless argv.empty?
          super unless argv.size <= 1
        else
          super
        end
        super unless argv.empty?
      end

      def run
        send @action
      end

      def create
        if repo_id_match = (@url || @name_or_url).match(/github.com\/([^\/\.]*\/[^\/\.]*)\.*/)
          # This is to make sure Faraday doesn't warn the user about the `system_timer` gem missing.
          old_warn, $-w = $-w, nil
          begin
            require 'faraday'
          ensure
            $-w = old_warn
          end
          require 'octokit'

          repo_id = repo_id_match[1]
          data = github_data_for_template(repo_id)
          data[:name] = @name_or_url if @url
          puts semantic_versioning_notice(repo_id, data[:name]) if data[:version] == '0.0.1'
        else
          data = default_data_for_template(@name_or_url)
        end
        spec = spec_template(data)
        (Pathname.pwd + "#{data[:name]}.podspec").open('w') { |f| f << spec }
        puts "\nSpecification created at #{data[:name]}.podspec".green
      end

      def lint
        puts
        invalid_count = lint_podspecs
        count = specs_to_lint.count
        if invalid_count == 0
          lint_passed_message = count == 1 ? "#{podspecs_to_lint.first.basename} passed validation." : "All the specs passed validation."
          puts lint_passed_message.green << "\n\n" unless config.silent?
        else
          raise Informative, count == 1 ? "The spec did not pass validation." : "#{invalid_count} out of #{count} specs failed validation."
        end
        podspecs_tmp_dir.rmtree if podspecs_tmp_dir.exist?
      end

      private

      def lint_podspecs
        invalid_count = 0
        specs_to_lint.each do |spec|
          # Show immediatly which pod is being processed.
          print " -> #{spec}\r" unless config.silent? || @multiple_files
          $stdout.flush

          linter          = Linter.new(spec)
          linter.lenient  = @only_errors
          linter.quick    = @quick || @multiple_files
          linter.no_clean = @no_clean
          invalid_count  += 1 unless linter.lint

          # This overwrites the previously printed text
          puts " -> ".send(lint_result_color(linter)) << spec.to_s unless config.silent? || should_skip?(linter)
          print_messages(spec, 'ERROR', linter.errors)
          print_messages(spec, 'WARN',  linter.warnings)
          print_messages(spec, 'NOTE',  linter.notes)

          puts unless config.silent? || should_skip?(linter)
        end
        puts "Analyzed #{specs_to_lint.count} specs in #{podspecs_to_lint.count} podspecs files.\n\n" if @multiple_files && !config.silent?
        invalid_count
      end

      def lint_result_color(linter)
        if linter.errors.empty? && linter.warnings.empty?
          :green
        elsif linter.errors.empty?
          :yellow
        else
          :red
        end
      end

      def should_skip?(linter)
        @multiple_files && linter.errors.empty? && linter.warnings.empty? && linter.notes.empty?
      end

      def print_messages(spec, type, messages)
        return if config.silent?
        messages.each {|msg| puts "    - #{type.ljust(5)} | #{msg}"}
      end

      def podspecs_to_lint
        @podspecs_to_lint ||= begin
          if @repo_or_podspec =~ /https?:\/\//
            require 'open-uri'
            output_path = podspecs_tmp_dir + File.basename(@repo_or_podspec)
            output_path.dirname.mkpath
            open(@repo_or_podspec) do |io|
              output_path.open('w') { |f| f << io.read }
            end
            return [output_path]
          end

          path = Pathname.new(@repo_or_podspec || '.')
          if path.directory?
            files = path.glob('**/*.podspec')
            raise Informative, "No specs found in the current directory." if files.empty?
            @multiple_files = true
          else
            files = [path]
            raise Informative, "Unable to find a spec named `#{@repo_or_podspec}'." unless files[0].exist? && @repo_or_podspec.include?('.podspec')
          end
          files
        end
      end

      def podspecs_tmp_dir
         Pathname.new('/tmp/CocoaPods/Lint_podspec')
      end

      def specs_to_lint
        @specs_to_lint ||= begin
          podspecs_to_lint.map do |podspec|
            root_spec = Specification.from_file(podspec)
            # TODO find a way to lint subspecs
            # root_spec.preferred_dependency ? root_spec.subspec_dependencies : root_spec
          end.flatten
        end
      end

      # Linter class
      #
      class Linter
        include Config::Mixin

        # TODO: Add check to ensure that attributes inherited by subspecs are not duplicated ?

        attr_accessor :quick, :lenient, :no_clean
        attr_reader   :spec, :file
        attr_reader   :errors, :warnings, :notes

        def initialize(spec)
          @spec = spec
          @file = spec.defined_in_file.realpath
        end

        # Takes an array of podspec files and lints them all
        #
        # It returns true if the spec passed validation
        #
        def lint
          @platform_errors, @platform_warnings, @platform_notes = {}, {}, {}

          platforms = @spec.available_platforms
          platforms.each do |platform|
            @platform_errors[platform], @platform_warnings[platform], @platform_notes[platform] = [], [], []

            @spec.activate_platform(platform)
            @platform = platform
            puts "\n\n#{spec} - Analyzing on #{platform} platform.".green.reversed if config.verbose? && !@quick

            # Skip validation if there are errors in the podspec as it would result in a crash
            if !podspec_errors.empty?
              @platform_errors[platform]   += podspec_errors
              @platform_notes[platform]    << "#{platform.name} [!] Fatal errors found skipping the rest of the validation"
            else
              @platform_warnings[platform] += podspec_warnings + deprecation_warnings
              peform_extensive_analysis unless quick
            end
          end

          # Get common messages
          @errors   = @platform_errors.values.reduce(:&)   || []
          @warnings = @platform_warnings.values.reduce(:&) || []
          @notes    = @platform_notes.values.reduce(:&)    || []

          platforms.each do |platform|
            # Mark platform specific messages
            @errors   += (@platform_errors[platform] - @errors).map {|m| "[#{platform}] #{m}"}
            @warnings += (@platform_warnings[platform] - @warnings).map {|m| "[#{platform}] #{m}"}
            @notes    += (@platform_notes[platform] - @notes).map {|m| "[#{platform}] #{m}"}
          end

          valid?
        end

        def valid?
          lenient ? errors.empty? : ( errors.empty? && warnings.empty? )
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
          @pod = installer.pods.find { |pod| pod.top_specification == @spec }
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
          spec.source && !spec.source =~ /http:\/\/EXAMPLE/
        end

        def paths_starting_with_a_slash_errors
          messages = []
          %w[source_files resources clean_paths].each do |accessor|
            patterns = spec.send(accessor.to_sym)
            # Some values are multiplaform
            patterns = patterns.is_a?(Hash) ? patterns.values.flatten(1) : patterns
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
          license  = @spec.license || {}
          source   = @spec.source  || {}
          text     = @file.read
          messages = []
          messages << "Missing license type"                                unless license[:type]
          messages << "Sample license type"                                 if license[:type] && license[:type] =~ /\(example\)/
          messages << "Invalid license type"                                if license[:type] && license[:type] =~ /\n/
          messages << "The summary is not meaningful"                       if spec.summary =~ /A short description of/
          messages << "The description is not meaningful"                   if spec.description && spec.description =~ /An optional longer description of/
          messages << "The summary should end with a dot"                   if @spec.summary !~ /.*\./
          messages << "The description should end with a dot"               if @spec.description !~ /.*\./ && @spec.description != @spec.summary
          messages << "Git sources should specify either a tag or a commit" if source[:git] && !source[:commit] && !source[:tag]
          messages << "Github repositories should end in `.git'"            if github_source? && source[:git] !~ /.*\.git/
          messages << "Github repositories should use `https' link"         if github_source? && source[:git] !~ /https:\/\/github.com/
          messages << "Comments must be deleted"                            if text.scan(/^\s*#/).length > 24
          messages
        end

        def github_source?
          @spec.source && @spec.source[:git] =~ /github.com/
        end

        # It reads a podspec file and checks for strings corresponding
        # to features that are or will be deprecated
        #
        # @return [Array<String>]
        #
        def deprecation_warnings
          text = @file.read
          deprecations = []
          deprecations << "`config.ios?' and `config.osx?' are deprecated"              if text. =~ /config\..?os.?/
          deprecations << "clean_paths are deprecated and ignored (use preserve_paths)" if text. =~ /clean_paths/
          deprecations
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
          messages << "The sources did not match any file"                     if !@spec.source_files.empty? && @pod.source_files.empty?
          messages << "The resources did not match any file"                   if !@spec.resources.empty? && @pod.resource_files.empty?
          messages << "The preserve_paths did not match any file"              if !@spec.preserve_paths.empty? && @pod.preserve_files.empty?
          messages << "The exclude_header_search_paths did not match any file" if !@spec.exclude_header_search_paths.empty? && @pod.headers_excluded_from_search_paths.empty?
          messages
        end

        def file_patterns_warnings
          messages = []
          unless @pod.license_file || @spec.license && ( @spec.license[:type] == 'Public Domain' || @spec.license[:text] )
            messages << "Unable to find a license file"
          end
          messages
        end
      end

      # Templates and github information retrival for spec create

      def default_data_for_template(name)
        data = {}
        data[:name]          = name
        data[:version]       = '0.0.1'
        data[:summary]       = "A short description of #{name}."
        data[:homepage]      = "http://EXAMPLE/#{name}"
        data[:author_name]   = `git config --get user.name`.strip
        data[:author_email]  = `git config --get user.email`.strip
        data[:source_url]    = "http://EXAMPLE/#{name}.git"
        data[:ref_type]      = ':tag'
        data[:ref]           = '0.0.1'
        data
      end

      def github_data_for_template(repo_id)
        repo = Octokit.repo(repo_id)
        user = Octokit.user(repo['owner']['login'])
        data = {}

        data[:name]          = repo['name']
        data[:summary]       = repo['description'].gsub(/["]/, '\"')
        data[:homepage]      = (repo['homepage'] && !repo['homepage'].empty? ) ? repo['homepage'] : repo['html_url']
        data[:author_name]   = user['name']  || user['login']
        data[:author_email]  = user['email'] || 'email@address.com'
        data[:source_url]    = repo['clone_url']

        data.merge suggested_ref_and_version(repo)
      end

      def suggested_ref_and_version(repo)
        tags = Octokit.tags(:username => repo['owner']['login'], :repo => repo['name']).map {|tag| tag["name"]}
        versions_tags = {}
        tags.each do |tag|
          clean_tag = tag.gsub(/^v(er)? ?/,'')
          versions_tags[Gem::Version.new(clean_tag)] = tag if Gem::Version.correct?(clean_tag)
        end
        version = versions_tags.keys.sort.last || '0.0.1'
        data = {:version => version}
        if version == '0.0.1'
          branches        = Octokit.branches(:username => repo['owner']['login'], :repo => repo['name'])
          master_name     = repo['master_branch'] || 'master'
          master          = branches.select {|branch| branch['name'] == master_name }.first
          data[:ref_type] = ':commit'
          data[:ref]      = master['commit']['sha']
        else
          data[:ref_type] = ':tag'
          data[:ref]      = versions_tags[version]
        end
        data
      end

      def spec_template(data)
        return <<-SPEC
#
# Be sure to run `pod spec lint #{data[:name]}.podspec' to ensure this is a
# valid spec.
#
# Remove all comments before submitting the spec. Optional attributes are commented.
#
# For details see: https://github.com/CocoaPods/CocoaPods/wiki/The-podspec-format
#
Pod::Spec.new do |s|
  s.name         = "#{data[:name]}"
  s.version      = "#{data[:version]}"
  s.summary      = "#{data[:summary]}"
  # s.description  = <<-DESC
  #                   An optional longer description of #{data[:name]}
  #
  #                   * Markdonw format.
  #                   * Don't worry about the indent, we strip it!
  #                  DESC
  s.homepage     = "#{data[:homepage]}"

  # Specify the license type. CocoaPods detects automatically the license file if it is named
  # `LICENSE*.*', however if the name is different, specify it.
  s.license      = 'MIT (example)'
  # s.license      = { :type => 'MIT (example)', :file => 'FILE_LICENSE' }
  #
  # Only if no dedicated file is available include the full text of the license.
  #
  # s.license      = {
  #   :type => 'MIT (example)',
  #   :text => <<-LICENSE
  #             Copyright (C) <year> <copyright holders>

  #             All rights reserved.

  #             Redistribution and use in source and binary forms, with or without
  #             ...
  #   LICENSE
  # }

  # Specify the authors of the library, with email addresses. You can often find
  # the email addresses of the authors by using the SCM log. E.g. $ git log
  #
  s.author       = { "#{data[:author_name]}" => "#{data[:author_email]}" }
  # s.authors      = { "#{data[:author_name]}" => "#{data[:author_email]}", "other author" => "and email address" }
  #
  # If absolutely no email addresses are available, then you can use this form instead.
  #
  # s.author       = '#{data[:author_name]}', 'other author'

  # Specify the location from where the source should be retreived.
  #
  s.source       = { :git => "#{data[:source_url]}", #{data[:ref_type]} => "#{data[:ref]}" }
  # s.source       = { :svn => 'http://EXAMPLE/#{data[:name]}/tags/1.0.0' }
  # s.source       = { :hg  => 'http://EXAMPLE/#{data[:name]}', :revision => '1.0.0' }

  # If this Pod runs only on iOS or OS X, then specify the platform and
  # the deployment target.
  #
  # s.platform     = :ios, '5.0'
  # s.platform     = :ios

  # ――― MULTI-PLATFORM VALUES ――――――――――――――――――――――――――――――――――――――――――――――――― #

  # If this Pod runs on both platforms, then specify the deployment
  # targets.
  #
  # s.ios.deployment_target = '5.0'
  # s.osx.deployment_target = '10.7'

  # A list of file patterns which select the source files that should be
  # added to the Pods project. If the pattern is a directory then the
  # path will automatically have '*.{h,m,mm,c,cpp}' appended.
  #
  # Alternatively, you can use the FileList class for even more control
  # over the selected files.
  # (See http://rake.rubyforge.org/classes/Rake/FileList.html.)
  #
  s.source_files = 'Classes', 'Classes/**/*.{h,m}'

  # A list of resources included with the Pod. These are copied into the
  # target bundle with a build phase script.
  #
  # Also allows the use of the FileList class like `source_files does.
  #
  # s.resource  = "icon.png"
  # s.resources = "Resources/*.png"

  # A list of paths to preserve after installing the Pod.
  # CocoaPods cleans by default any file that is not used.
  # Please don't include documentation, example, and test files.
  # Also allows the use of the FileList class like `source_files does.
  #
  # s.preserve_paths = "FilesToSave", "MoreFilesToSave"

  # Specify a list of frameworks that the application needs to link
  # against for this Pod to work.
  #
  # s.framework  = 'SomeFramework'
  # s.frameworks = 'SomeFramework', 'AnotherFramework'

  # Specify a list of libraries that the application needs to link
  # against for this Pod to work.
  #
  # s.library   = 'iconv'
  # s.libraries = 'iconv', 'xml2'

  # If this Pod uses ARC, specify it like so.
  #
  # s.requires_arc = true

  # If you need to specify any other build settings, add them to the
  # xcconfig hash.
  #
  # s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

  # Finally, specify any Pods that this Pod depends on.
  #
  # s.dependency 'JSONKit', '~> 1.4'
end
      SPEC
    end

      def semantic_versioning_notice(repo_id, repo)
        return <<-EOS

#{'――― MARKDOWN TEMPLATE ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――'.reversed}

I’ve recently added [#{repo}](https://github.com/CocoaPods/Specs/tree/master/#{repo}) to the [CocoaPods](https://github.com/CocoaPods/CocoaPods) package manager repo.

CocoaPods is a tool for managing dependencies for OSX and iOS Xcode projects and provides a central repository for iOS/OSX libraries. This makes adding libraries to a project and updating them extremely easy and it will help users to resolve dependencies of the libraries they use.

However, #{repo} doesn't have any version tags. I’ve added the current HEAD as version 0.0.1, but a version tag will make dependency resolution much easier.

[Semantic version](http://semver.org) tags (instead of plain commit hashes/revisions) allow for [resolution of cross-dependencies](https://github.com/CocoaPods/Specs/wiki/Cross-dependencies-resolution-example).

In case you didn’t know this yet; you can tag the current HEAD as, for instance, version 1.0.0, like so:

```
$ git tag -a 1.0.0 -m "Tag release 1.0.0"
$ git push --tags
```

#{'――― TEMPLATE END ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――'.reversed}

#{'[!] This repo does not appear to have semantic version tags.'.yellow}

After commiting the specification, consider opening a ticket with the template displayed above:
  - link:  https://github.com/#{repo_id}/issues/new
  - title: Please add semantic version tags
        EOS
      end
    end
  end
end
