# encoding: utf-8

module Pod
  class Command
    class Spec < Command
      def self.banner
        %{Managing PodSpec files:

    $ pod spec create [ NAME | https://github.com/USER/REPO ]

      Creates a PodSpec, in the current working dir, called `NAME.podspec'.
      If a GitHub url is passed the spec is prepopulated.

    $ pod spec lint [ NAME.podspec | REPO ]

      Validates `NAME.podspec'. In case `NAME.podspec' is omitted, it defaults
      to `*.podspec' in the current working dir. If the name of a repo is
      provided it validates all its specs.}
      end

      def self.options
        [ ["--quick", "Lint skips checks that would require to donwload and build the spec"],
          ["--only-errors", "Lint validates even if warnings are present"] ].concat(super)
      end

      def initialize(argv)
        @action = argv.shift_argument
        if @action == 'create'
          @name_or_url = argv.shift_argument
          @url = argv.shift_argument
          super if @name_or_url.nil?
        elsif @action == 'lint'
          @quick  = argv.option('--quick')
          @only_errors = argv.option('--only-errors')
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
        if (is_repo = repo_with_name_exist(@repo_or_podspec))
          files = (config.repos_dir + @repo_or_podspec).glob('**/*.podspec')
        else
          if @repo_or_podspec
            files = [Pathname.new(@repo_or_podspec)]
            raise Informative, "[!] Unable to find a spec named #{@repo_or_podspec}".red unless files[0].exist? && @repo_or_podspec.include?('.podspec')
          else
            files = Pathname.pwd.glob('*.podspec')
            raise Informative, "[!] No specs found in the current directory".red if files.empty?
          end
        end
        puts
        all_valid = Linter.new(files, is_repo).lint!
        if all_valid
          puts (files.count == 1 ? "#{files[0].basename} passed validation" : "All the specs passed validation").green << "\n\n"
        else
          message = (files.count == 1 ?  "[!] The spec did not pass validation" : "[!] Not all specs passed validation").red
        raise Informative, message
        end
      end

      def repo_with_name_exist(name)
        name && (config.repos_dir + name).exist? && !name.include?('/')
      end

      class Linter
        include Config::Mixin

        def initialize(files, is_repo)
          @files = files
          @is_repo = is_repo
        end

        # Takes an array of podspec files and lints them all
        #
        # It returns true if **all** the files passed validation
        #
        def lint!
          all_valid = true
          @files.each do |file|
            file = file.realpath
            file_spec = Specification.from_file(file)

            specs = file_spec.recursive_subspecs.any? ?  file_spec.recursive_subspecs : [file_spec]
            specs.each do |spec|
              # Show immediatly which pod is being processed.
              # This line will be overwritten once the result is known
              print " -> #{spec}\r" unless config.silent? || @is_repo
              $stdout.flush

              # If the spec doesn't validate it raises and informative
              spec.validate!

              warnings     = warnings_for_spec(spec, file)
              deprecations = deprecation_notices_for_spec(spec, file)
              build_messages, file_patterns_errors = [], []
              unless @is_repo || @quick
                platform_names(spec).each do |platform_name|
                  set_up_lint_environment
                  build_messages       += build_errors_for_spec(spec, file, platform_name)
                  file_patterns_errors += file_patterns_errors_for_spec(spec, file, platform_name)
                  tear_down_lint_environment
                end
              end
              build_errors   = build_messages.select {|msg| msg.include?('error')}
              build_warnings = build_messages - build_errors

              # Errors compromise the functionality of a spec, warnings can be ignored
              all            = warnings + deprecations + build_messages + file_patterns_errors
              errors         = file_patterns_errors + build_errors
              warnings       = all - errors

              if @only_errors
                all_valid = false unless errors.empty?
              else
                # avoid to fail validation for xcode warnings
                all_valid = false unless (all - build_warnings).empty?
              end

              clean_duplicate_platfrom_messages(errors)
              clean_duplicate_platfrom_messages(warnings)

              # This overwrites the previously printed text
              unless config.silent?
                if errors.empty? && warnings.empty?
                  puts " -> ".green + "#{spec} passed validation" unless @is_repo
                elsif errors.empty?
                  puts " -> ".yellow + spec.to_s
                else
                  puts " -> ".red + spec.to_s
                end
              end

              warnings.each {|msg| puts "    - WARN  | #{msg}"} unless config.silent?
              errors.each   {|msg| puts "    - ERROR | #{msg}"} unless config.silent?
              puts unless config.silent? || ( @is_repo && all.flatten.empty? )
            end
          end
          all_valid
        end

        def tmp_dir
          Pathname.new('/tmp/CocoaPods/Lint')
        end

        def set_up_lint_environment
          tmp_dir.rmtree if tmp_dir.exist?
          tmp_dir.mkpath
          @original_config = Config.instance.clone
          config.project_root      = tmp_dir
          config.project_pods_root = tmp_dir + 'Pods'
          config.silent            = !config.verbose
          config.integrate_targets = false
          config.doc_install       = false
        end

        def tear_down_lint_environment
          tmp_dir.rmtree
          Config.instance = @original_config
        end

        def clean_duplicate_platfrom_messages(messages)
          duplicate_candiates = messages.select {|l| l.include?("ios: ")}
          duplicated = duplicate_candiates.select {|l| messages.include?(l.gsub(/ios: /,'osx: ')) }
          duplicated.uniq.each do |l|
            clean = l.gsub(/ios: /,'')
            messages.insert(messages.index(l), clean)
            messages.delete(l)
            messages.delete('osx: ' + clean)
          end
        end

        # It checks a spec for minor non fatal defects
        #
        # It returns a array of messages
        #
        def warnings_for_spec(spec, file)
          license  = spec.license
          source   = spec.source
          text     = file.read
          warnings = []
          warnings << "The name of the spec should match the name of the file" unless path_matches_name?(file, spec)
          warnings << "Missing license[:type]" unless license && license[:type]
          warnings << "Github repositories should end in `.git'" if source && source[:git] =~ /github.com/ && source[:git] !~ /.*\.git/
          warnings << "Github repositories should start with `https'" if source && source[:git] =~ /github.com/ && source[:git] !~ /https:\/\/github.com/
          warnings << "The description should end with a dot" if spec.description != spec.summary && spec.description !~ /.*\./
          warnings << "The summary should end with a dot" if spec.summary !~ /.*\./
          warnings << "Missing license[:file] or [:text]" unless license && (license[:file] || license[:text])
          warnings << "Comments must be deleted" if text =~ /^\w*#\n\w*#/ # allow a single line comment as it is generally used in subspecs
            warnings
        end

        def path_matches_name?(file, spec)
          spec_name = spec.name.match(/[^\/]*/)[0]
          file.basename.to_s == spec_name + '.podspec'
        end

        # It reads a podspec file and checks for strings corresponding
        # to a feature that are or will be deprecated
        #
        # It returns a array of messages
        #
        def deprecation_notices_for_spec(spec, file)
          text = file.read
          deprecations = []
          deprecations << "`config.ios?' and `config.osx' will be removed in version 0.7" if text. =~ /config\..os?/
          deprecations << "The `post_install' hook is reserved for edge cases" if text. =~ /post_install/
          deprecations
        end

        # It creates a podfile in memory and builds a library containing
        # the pod for all available platfroms with xcodebuild.
        #
        # It returns a array of messages
        #
        def build_errors_for_spec(spec, file, platform_name)
          messages = []
          puts "\n\n#{spec} - generating build errors for #{platform_name} platform".yellow.reversed if config.verbose?
          podfile = podfile_from_spec(spec, file, platform_name)
          Installer.new(podfile).install!

          return messages if `which xcodebuild`.strip.empty?
          output        = Dir.chdir(config.project_pods_root) { `xcodebuild 2>&1` }
          clean_output  = process_xcode_build_output(output).map {|l| "#{platform_name}: #{l}"}
          messages     += clean_output
          puts(output) if config.verbose?
          messages
        end

        def podfile_from_spec(spec, file, platform_name)
          podfile = Pod::Podfile.new do
            platform platform_name
            dependency spec.name, :podspec => file.realpath.to_s
          end
        end

        def process_xcode_build_output(output)
          output_by_line = output.split("\n")
          selected_lines = output_by_line.select do |l|
            l.include?('error') && (l !~ /errors? generated\./) \
              || l.include?('warning') && (l !~ /warnings? generated\./)\
              || l.include?('note')
          end
          # Remove the unnecessary tmp path
          selected_lines.map {|l| l.gsub(/\/tmp\/CocoaPods\/Lint\/Pods\//,'')}
        end

        # It checks that every file pattern specified in a spec yields
        # at least one file. It requires the pods to be alredy present
        # in the current working directory under Pods/spec.name
        #
        # It returns a array of messages
        #
        def file_patterns_errors_for_spec(spec, file, platform_name)
          Dir.chdir(config.project_pods_root + spec.name ) do
            messages = []
            messages += check_spec_files_exists(spec, :source_files, platform_name, '*.{h,m,mm,c,cpp}')
            messages += check_spec_files_exists(spec, :resources, platform_name)
            messages << "license[:file] = '#{spec.license[:file]}' -> did not match any file" if spec.license[:file] && Pathname.pwd.glob(spec.license[:file]).empty?
            messages.compact
          end
        end

        # TODO: FileList doesn't work and always adds the error message
        # pod spec lint ~/.cocoapods/master/MKNetworkKit/0.83/MKNetworkKit.podspec
        def check_spec_files_exists(spec, accessor, platform_name, options = {})
          result = []
          patterns = spec.send(accessor)[platform_name]
          patterns.map do |pattern|
            pattern = Pathname.pwd + pattern
            if pattern.directory? && options[:glob]
              pattern += options[:glob]
            end
            result << "#{platform_name}: [#{accessor} = '#{pattern}'] -> did not match any file" if pattern.glob.empty?
          end
          result
        end

        def platform_names(spec)
          spec.platform.name ? [spec.platform.name] : [:ios, :osx]
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
        data[:homepage]      = repo['homepage'] != "" ? repo['homepage'] : repo['html_url']
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
# Remove all comments before submitting the spec.
#
Pod::Spec.new do |s|

  # ――― REQUIRED VALUES ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  s.name      = "#{data[:name]}"
  s.version   = "#{data[:version]}"
  s.summary   = "#{data[:summary]}"
  s.homepage  = "#{data[:homepage]}"

  # Specify the authors of the library, with email addresses. You can often find
  # the email addresses of the authors by using the SCM log. E.g. $ git log
  #
  s.author    = { "#{data[:author_name]}" => "#{data[:author_email]}" }
  # s.authors = { "#{data[:author_name]}" => "#{data[:author_email]}", "other author" => "and email address" }
  #
  # If absolutely no email addresses are available, then you can use this form instead.
  #
  # s.author   = '#{data[:author_name]}', 'other author'

  # Specify the location from where the source should be retreived.
  #
  s.source    = { :git => "#{data[:source_url]}", #{data[:ref_type]} => "#{data[:ref]}" }
  # s.source   = { :svn => 'http://EXAMPLE/#{data[:name]}/tags/1.0.0' }
  # s.source   = { :hg  => 'http://EXAMPLE/#{data[:name]}', :revision => '1.0.0' }

  # Specify the license details. Only if no dedicated file is available include
  # the full text of the license.
  #
  s.license  = {
    :type => 'MIT',
    :file => 'LICENSE',
  #  :text => 'Permission is hereby granted ...'
  }

  # A list of file patterns which select the source files that should be
  # added to the Pods project. If the pattern is a directory then the
  # path will automatically have '*.{h,m,mm,c,cpp}' appended.
  #
  # Alternatively, you can use the FileList class for even more control
  # over the selected files.
  # (See http://rake.rubyforge.org/classes/Rake/FileList.html.)
  #
  s.source_files = 'Classes', 'Classes/**/*.{h,m}'

  # ――― OPTIONAL VALUES ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  s.description = 'An optional longer description of #{data[:name]}.'

  # If this Pod runs only on iOS or OS X, then specify that with one of
  # these, or none if it runs on both platforms.
  # If the pod runs on both plafroms but presents different deployment
  # targets, source files, etc. create two different pods: `#{data[:name]}-iOS'
  # and `#{data[:name]}-OSX'.
  #
  # s.platform = :ios
  # s.platform = :ios, { :deployment_target => "5.0" }
  # s.platform = :osx
  # s.platform = :osx, { :deployment_target => "10.7" }

  # A list of resources included with the Pod. These are copied into the
  # target bundle with a build phase script.
  #
  # Also allows the use of the FileList class like `source_files does.
  #
  # s.resource  = "icon.png"
  # s.resources = "Resources/*.png"

  # A list of paths to remove after installing the Pod without the
  # `--no-clean' option. These can be examples, docs, and any other type
  # of files that are not needed to build the Pod.
  #
  # *NOTE*: Never remove license and README files.
  #
  # Also allows the use of the FileList class like `source_files does.
  #
  # s.clean_path  = "examples"
  # s.clean_paths = "examples", "doc"

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

  # Finally, specify any Pods that this Pod depends on.
  #
  # s.dependency 'JSONKit', '~> 1.4'

        # ――― EXTRA VALUES ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  # If you need to specify any other build settings, add them to the
  # xcconfig hash.
  #
  # s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

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
