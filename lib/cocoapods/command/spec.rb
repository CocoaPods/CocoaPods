# encoding: utf-8

require 'active_support/core_ext/string/inflections'

module Pod
  class Command
    class Spec < Command
      self.abstract_command = true
      self.summary = 'Manage pod specs'

      #-----------------------------------------------------------------------#

      class Create < Spec
        self.summary = 'Create spec file stub.'

        self.description = <<-DESC
          Creates a PodSpec, in the current working dir, called `NAME.podspec'.
          If a GitHub url is passed the spec is prepopulated.
        DESC

        self.arguments = [
          CLAide::Argument.new(%w(NAME https://github.com/USER/REPO), false),
        ]

        def initialize(argv)
          @name_or_url, @url = argv.shift_argument, argv.shift_argument
          super
        end

        def validate!
          super
          help! 'A pod name or repo URL is required.' unless @name_or_url
        end

        def run
          if repo_id_match = (@url || @name_or_url).match(/github.com\/([^\/\.]*\/[^\/\.]*)\.*/)
            repo_id = repo_id_match[1]
            data = github_data_for_template(repo_id)
            data[:name] = @name_or_url if @url
            UI.puts semantic_versioning_notice(repo_id, data[:name]) if data[:version] == '0.0.1'
          else
            data = default_data_for_template(@name_or_url)
          end
          spec = spec_template(data)
          (Pathname.pwd + "#{data[:name]}.podspec").open('w') { |f| f << spec }
          UI.puts "\nSpecification created at #{data[:name]}.podspec".green
        end
      end

      #-----------------------------------------------------------------------#

      class Lint < Spec
        self.summary = 'Validates a spec file.'

        self.description = <<-DESC
          Validates `NAME.podspec`. If a `DIRECTORY` is provided, it validates
          the podspec files found, including subfolders. In case
          the argument is omitted, it defaults to the current working dir.
        DESC

        self.arguments = [
          CLAide::Argument.new(%w(NAME.podspec DIRECTORY http://PATH/NAME.podspec), false, true),
        ]

        def self.options
          [['--quick', 'Lint skips checks that would require to download and build the spec'],
           ['--allow-warnings', 'Lint validates even if warnings are present'],
           ['--subspec=NAME', 'Lint validates only the given subspec'],
           ['--no-subspecs', 'Lint skips validation of subspecs'],
           ['--no-clean', 'Lint leaves the build directory intact for inspection'],
           ['--sources=https://github.com/artsy/Specs', 'The sources from which to pull dependant pods ' \
            '(defaults to https://github.com/CocoaPods/Specs.git). '\
            'Multiple sources must be comma-delimited.']].concat(super)
        end

        def initialize(argv)
          @quick           = argv.flag?('quick')
          @allow_warnings  = argv.flag?('allow-warnings')
          @clean           = argv.flag?('clean', true)
          @subspecs        = argv.flag?('subspecs', true)
          @only_subspec    = argv.option('subspec')
          @source_urls     = argv.option('sources', 'https://github.com/CocoaPods/Specs.git').split(',')
          @podspecs_paths = argv.arguments!
          super
        end

        def run
          UI.puts
          invalid_count = 0
          podspecs_to_lint.each do |podspec|
            validator                = Validator.new(podspec, @source_urls)
            validator.quick          = @quick
            validator.no_clean       = !@clean
            validator.allow_warnings = @allow_warnings
            validator.no_subspecs    = !@subspecs || @only_subspec
            validator.only_subspec   = @only_subspec
            validator.validate
            invalid_count += 1 unless validator.validated?

            unless @clean
              UI.puts "Pods project available at `#{validator.validation_dir}/Pods/Pods.xcodeproj` for inspection."
              UI.puts
            end
          end

          count = podspecs_to_lint.count
          UI.puts "Analyzed #{count} #{'podspec'.pluralize(count)}.\n\n"
          if invalid_count == 0
            lint_passed_message = count == 1 ? "#{podspecs_to_lint.first.basename} passed validation." : 'All the specs passed validation.'
            UI.puts lint_passed_message.green << "\n\n"
          else
            raise Informative, count == 1 ? 'The spec did not pass validation.' : "#{invalid_count} out of #{count} specs failed validation."
          end
          podspecs_tmp_dir.rmtree if podspecs_tmp_dir.exist?
        end

        private

        def podspecs_to_lint
          @podspecs_to_lint ||= begin
            files = []
            @podspecs_paths << '.' if @podspecs_paths.empty?
            @podspecs_paths.each do |path|
              if path =~ /https?:\/\//
                require 'open-uri'
                output_path = podspecs_tmp_dir + File.basename(path)
                output_path.dirname.mkpath
                open(path) do |io|
                  output_path.open('w') { |f| f << io.read }
                end
                files << output_path
              elsif (pathname = Pathname.new(path)).directory?
                files += Pathname.glob(pathname + '**/*.podspec{.json,}')
                raise Informative, 'No specs found in the current directory.' if files.empty?
              else
                files << (pathname = Pathname.new(path))
                raise Informative, "Unable to find a spec named `#{path}'." unless pathname.exist? && path.include?('.podspec')
              end
            end
            files
          end
        end

        def podspecs_tmp_dir
          Pathname(File.join(Pathname.new('/tmp').realpath, '/CocoaPods/Lint_podspec'))
        end
      end

      #-----------------------------------------------------------------------#

      class Which < Spec
        self.summary = 'Prints the path of the given spec.'

        self.description = <<-DESC
          Prints the path of the .podspec file(s) whose name matches `QUERY`
        DESC

        self.arguments = [
          CLAide::Argument.new('QUERY', false),
        ]

        def self.options
          [
            ['--regex', 'Interpret the `QUERY` as a regular expression'],
            ['--show-all', 'Print all versions of the given podspec'],
          ].concat(super)
        end

        def initialize(argv)
          @use_regex = argv.flag?('regex')
          @show_all = argv.flag?('show-all')
          @query = argv.shift_argument
          @query = @query.gsub('.podspec', '') unless @query.nil?
          super
        end

        def validate!
          super
          help! 'A podspec name is required.' unless @query
          validate_regex!(@query) if @use_regex
        end

        def run
          query = @use_regex ? @query : Regexp.escape(@query)
          UI.puts get_path_of_spec(query, @show_all)
        end
      end

      #-----------------------------------------------------------------------#

      class Cat < Spec
        self.summary = 'Prints a spec file.'

        self.description = <<-DESC
          Prints the content of the podspec(s) whose name matches `QUERY` to standard output.
        DESC

        self.arguments = [
          CLAide::Argument.new('QUERY', false),
        ]

        def self.options
          [
            ['--regex', 'Interpret the `QUERY` as a regular expression'],
            ['--show-all', 'Pick from all versions of the given podspec']
          ].concat(super)
        end

        def initialize(argv)
          @use_regex = argv.flag?('regex')
          @show_all = argv.flag?('show-all')
          @query = argv.shift_argument
          @query = @query.gsub('.podspec', '') unless @query.nil?
          super
        end

        def validate!
          super
          help! 'A podspec name is required.' unless @query
          validate_regex!(@query) if @use_regex
        end

        def run
          query = @use_regex ? @query : Regexp.escape(@query)
          filepath = if @show_all
                       specs = get_path_of_spec(query, @show_all).split(/\n/)
                       index = choose_from_array(specs, "Which spec would you like to print [1-#{ specs.count }]? ")
                       specs[index]
                     else
                       get_path_of_spec(query)
                     end

          UI.puts File.read(filepath)
        end
      end

      #-----------------------------------------------------------------------#

      class Edit < Spec
        self.summary = 'Edit a spec file.'

        self.description = <<-DESC
          Opens the podspec matching `QUERY` to be edited.
        DESC

        self.arguments = [
          CLAide::Argument.new('QUERY', false),
        ]

        def self.options
          [
            ['--regex', 'Interpret the `QUERY` as a regular expression'],
            ['--show-all', 'Pick from all versions of the given podspec']
          ].concat(super)
        end

        def initialize(argv)
          @use_regex = argv.flag?('regex')
          @show_all = argv.flag?('show-all')
          @query = argv.shift_argument
          @query = @query.gsub('.podspec', '') unless @query.nil?
          super
        end

        def validate!
          super
          help! 'A podspec name is required.' unless @query
          validate_regex!(@query) if @use_regex
        end

        def run
          query = @use_regex ? @query : Regexp.escape(@query)
          if @show_all
            specs = get_path_of_spec(query, @show_all).split(/\n/)
            message = "Which spec would you like to edit [1-#{specs.count}]? "
            index = choose_from_array(specs, message)
            filepath = specs[index]
          else
            filepath = get_path_of_spec(query)
          end

          exec_editor(filepath.to_s) if File.exist? filepath
          raise Informative, "#{ filepath } doesn't exist."
        end

        # Thank you homebrew
        def which(cmd)
          dir = ENV['PATH'].split(':').find { |p| File.executable? File.join(p, cmd) }
          Pathname.new(File.join(dir, cmd)) unless dir.nil?
        end

        def which_editor
          editor = ENV['EDITOR']
          # If an editor wasn't set, try to pick a sane default
          return editor unless editor.nil?

          # Find Sublime Text 2
          return 'subl' if which 'subl'
          # Find Textmate
          return 'mate' if which 'mate'
          # Find # BBEdit / TextWrangler
          return 'edit' if which 'edit'
          # Default to vim
          return 'vim' if which 'vim'

          raise Informative, "Failed to open editor. Set your 'EDITOR' environment variable."
        end

        def exec_editor(*args)
          return if args.to_s.empty?
          safe_exec(which_editor, *args)
        end

        def safe_exec(cmd, *args)
          # This buys us proper argument quoting and evaluation
          # of environment variables in the cmd parameter.
          exec('/bin/sh', '-i', '-c', cmd + ' "$@"', '--', *args)
        end
      end

      #-----------------------------------------------------------------------#

      # @todo some of the following methods can probably move to one of the
      #       subclasses.

      private

      # @param [String] query the regular expression string to validate
      #
      # @raise if the query is not a valid regular expression
      #
      def validate_regex!(query)
        /#{query}/
      rescue RegexpError
        help! 'A valid regular expression is required.'
      end

      # @return [Fixnum] the index of the chosen array item
      #
      def choose_from_array(array, message)
        array.each_with_index do |item, index|
          UI.puts "#{ index + 1 }: #{ item }"
        end

        UI.puts message

        index = UI.gets.chomp.to_i - 1
        if index < 0 || index > array.count - 1
          raise Informative, "#{ index + 1 } is invalid [1-#{ array.count }]"
        else
          index
        end
      end

      # @param  [String] spec
      #         The name of the specification.
      #
      # @param  [Bool] show_all
      #         Whether the paths for all the versions should be returned or
      #         only the one for the last version.
      #
      # @return [Pathname] the absolute path or paths of the given podspec
      #
      def get_path_of_spec(spec, show_all = false)
        sets = SourcesManager.search_by_name(spec)

        if sets.count == 1
          set = sets.first
        elsif sets.map(&:name).include?(spec)
          set = sets.find { |s| s.name == spec }
        else
          names = sets.map(&:name) * ', '
          raise Informative, "More than one spec found for '#{ spec }':\n#{ names }"
        end

        unless show_all
          best_spec, spec_source = spec_and_source_from_set(set)
          return pathname_from_spec(best_spec, spec_source)
        end

        all_paths_from_set(set)
      end

      # @return [Pathname] the absolute path of the given spec and source
      #
      def pathname_from_spec(spec, _source)
        Pathname(spec.defined_in_file)
      end

      # @return [String] of spec paths one on each line
      #
      def all_paths_from_set(set)
        paths = ''

        sources = set.sources

        sources.each do |source|
          versions = source.versions(set.name)

          versions.each do |version|
            spec = source.specification(set.name, version)
            paths += "#{ pathname_from_spec(spec, source) }\n"
          end
        end

        paths
      end

      # @return [Specification, Source] the highest known specification with it's source of the given
      #         set.
      #
      def spec_and_source_from_set(set)
        sources = set.sources

        best_source = best_version = nil
        sources.each do |source|
          versions = source.versions(set.name)
          versions.each do |version|
            if !best_version || version > best_version
              best_source = source
              best_version = version
            end
          end
        end

        if !best_source || !best_version
          raise Informative, "Unable to locate highest known specification for `#{ set.name }'"
        end

        [best_source.specification(set.name, best_version), best_source]
      end

      #--------------------------------------#

      # Templates and github information retrieval for spec create
      #
      # @todo It would be nice to have a template class that accepts options
      #       and uses the default ones if not provided.
      # @todo The template is outdated.

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
        repo = GitHub.repo(repo_id)
        raise Informative, "Unable to fetch data for `#{repo_id}`" unless repo
        user = GitHub.user(repo['owner']['login'])
        raise Informative, "Unable to fetch data for `#{repo['owner']['login']}`" unless user
        data = {}

        data[:name]          = repo['name']
        data[:summary]       = (repo['description'] || '').gsub(/["]/, '\"')
        data[:homepage]      = (repo['homepage'] && !repo['homepage'].empty?) ? repo['homepage'] : repo['html_url']
        data[:author_name]   = user['name']  || user['login']
        data[:author_email]  = user['email'] || 'email@address.com'
        data[:source_url]    = repo['clone_url']

        data.merge suggested_ref_and_version(repo)
      end

      def suggested_ref_and_version(repo)
        tags = GitHub.tags(repo['html_url']).map { |tag| tag['name'] }
        versions_tags = {}
        tags.each do |tag|
          clean_tag = tag.gsub(/^v(er)? ?/, '')
          versions_tags[Gem::Version.new(clean_tag)] = tag if Gem::Version.correct?(clean_tag)
        end
        version = versions_tags.keys.sort.last || '0.0.1'
        data = { :version => version }
        if version == '0.0.1'
          branches        = GitHub.branches(repo['html_url'])
          master_name     = repo['master_branch'] || 'master'
          master          = branches.find { |branch| branch['name'] == master_name }
          raise Informative, "Unable to find any commits on the master branch for the repository `#{repo['html_url']}`" unless master
          data[:ref_type] = ':commit'
          data[:ref]      = master['commit']['sha']
        else
          data[:ref_type] = ':tag'
          data[:ref]      = versions_tags[version]
        end
        data
      end

      def spec_template(data)
        <<-SPEC
#
#  Be sure to run `pod spec lint #{data[:name]}.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  These will help people to find your library, and whilst it
  #  can feel like a chore to fill in it's definitely to your advantage. The
  #  summary should be tweet-length, and the description more in depth.
  #

  s.name         = "#{data[:name]}"
  s.version      = "#{data[:version]}"
  s.summary      = "#{data[:summary]}"

  s.description  = <<-DESC
                   A longer description of #{data[:name]} in Markdown format.

                   * Think: Why did you write this? What is the focus? What does it do?
                   * CocoaPods will be using this to generate tags, and improve search results.
                   * Try to keep it short, snappy and to the point.
                   * Finally, don't worry about the indent, CocoaPods strips it!
                   DESC

  s.homepage     = "#{data[:homepage]}"
  # s.screenshots  = "www.example.com/screenshots_1.gif", "www.example.com/screenshots_2.gif"


  # ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Licensing your code is important. See http://choosealicense.com for more info.
  #  CocoaPods will detect a license file if there is a named LICENSE*
  #  Popular ones are 'MIT', 'BSD' and 'Apache License, Version 2.0'.
  #

  s.license      = "MIT (example)"
  # s.license      = { :type => "MIT", :file => "FILE_LICENSE" }


  # ――― Author Metadata  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Specify the authors of the library, with email addresses. Email addresses
  #  of the authors are extracted from the SCM log. E.g. $ git log. CocoaPods also
  #  accepts just a name if you'd rather not provide an email address.
  #
  #  Specify a social_media_url where others can refer to, for example a twitter
  #  profile URL.
  #

  s.author             = { "#{data[:author_name]}" => "#{data[:author_email]}" }
  # Or just: s.author    = "#{data[:author_name]}"
  # s.authors            = { "#{data[:author_name]}" => "#{data[:author_email]}" }
  # s.social_media_url   = "http://twitter.com/#{data[:author_name]}"

  # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If this Pod runs only on iOS or OS X, then specify the platform and
  #  the deployment target. You can optionally include the target after the platform.
  #

  # s.platform     = :ios
  # s.platform     = :ios, "5.0"

  #  When using multiple platforms
  # s.ios.deployment_target = "5.0"
  # s.osx.deployment_target = "10.7"


  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Specify the location from where the source should be retrieved.
  #  Supports git, hg, bzr, svn and HTTP.
  #

  s.source       = { :git => "#{data[:source_url]}", #{data[:ref_type]} => "#{data[:ref]}" }


  # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  CocoaPods is smart about how it includes source code. For source files
  #  giving a folder will include any h, m, mm, c & cpp files. For header
  #  files it will include any header in the folder.
  #  Not including the public_header_files will make all headers public.
  #

  s.source_files  = "Classes", "Classes/**/*.{h,m}"
  s.exclude_files = "Classes/Exclude"

  # s.public_header_files = "Classes/**/*.h"


  # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  A list of resources included with the Pod. These are copied into the
  #  target bundle with a build phase script. Anything else will be cleaned.
  #  You can preserve files from being cleaned, please don't preserve
  #  non-essential files like tests, examples and documentation.
  #

  # s.resource  = "icon.png"
  # s.resources = "Resources/*.png"

  # s.preserve_paths = "FilesToSave", "MoreFilesToSave"


  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Link your library with frameworks, or libraries. Libraries do not include
  #  the lib prefix of their name.
  #

  # s.framework  = "SomeFramework"
  # s.frameworks = "SomeFramework", "AnotherFramework"

  # s.library   = "iconv"
  # s.libraries = "iconv", "xml2"


  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If your library depends on compiler flags you can set them in the xcconfig hash
  #  where they will only apply to your library. If you depend on other Podspecs
  #  you can include multiple dependencies to ensure it works.

  # s.requires_arc = true

  # s.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }
  # s.dependency "JSONKit", "~> 1.4"

end
      SPEC
    end

      def semantic_versioning_notice(repo_id, repo)
        <<-EOS

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
