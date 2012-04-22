# encoding: utf-8

require 'net/https'
require 'uri'
require 'octokit'
require 'json'

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

      def initialize(argv)
        args = argv.arguments
        unless (args[0] == 'create' && args.size == 2) ||
          (args[0] == 'lint' && args.size <= 2)
          super
        end
        @action, @name_or_url = args.first(2)
      end

      def run
        send @action
      end

      def create
        if repo_id = @name_or_url[/github.com\/([^\/\.]*\/[^\/\.]*)\.*/, 1]
          data = github_data_for_template(repo_id)
          puts semantic_versioning_notice(repo_id, data[:name]) if data[:version] == '0.0.1'
        else
          data = default_data_for_template(@name_or_url)
        end
        spec = spec_template(data)
        (Pathname.pwd + "#{data[:name]}.podspec").open('w') { |f| f << spec }
        puts "\nSpecification created at #{data[:name]}.podspec".green
      end

      def lint
        is_repo = repo_with_name_exist(@name_or_url)
        if is_repo
          files = (config.repos_dir + @name_or_url).glob('**/*.podspec')
        else
          name = @name_or_url
          files = name ? [Pathname.new(name)] : Pathname.pwd.glob('*.podspec')
        end
        puts
        lint_specs_files(files, is_repo)
      end

      private

      def repo_with_name_exist(name)
        name && (config.repos_dir + name).exist?
      end

      # Takes an array of podspec files and lints them all
      #
      # It returns true if **all** the files passed validation
      #
      def lint_specs_files(files, is_repo)
        tmp_dir = Pathname.new('/tmp/CocoaPods/Lint')
        all_valid = true
        files.each do |file|
          file = file.realpath
          spec = Specification.from_file(file)
          print " -> #{spec}\r" unless config.silent? || is_repo

          spec.validate!
          warnings     = warnings_for_spec(spec, file, is_repo)
          deprecations = deprecation_notices_for_spec(spec, file, is_repo)
          # TODO: check that the dependencies of the spec exist
          if is_repo
            build_errors, file_errors = [], []
          else
            tmp_dir.mkpath
            build_errors = Dir.chdir(tmp_dir) { build_errors_for_spec(spec, file, is_repo) }
            file_errors  = Dir.chdir(tmp_dir) { file_errors_for_spec(spec, file, is_repo) }
            tmp_dir.rmtree
          end

          # This overwrites the previous printed text
          is_valid = deprecations.empty? && warnings.empty? && file_errors.empty?
          unless config.silent?
            if is_valid
              puts " -> ".green + "#{spec} passed validation" unless is_repo
            else
              puts " -> ".red + spec.to_s
              all_valid = false
            end
          end
          types    = ["WARN", "DPRC", "XCDB", "ERFL"]
          messages = [warnings, deprecations, build_errors, file_errors]
          types.each_with_index do |type, i|
            unless messages[i].empty?
              messages[i].each {|msg| puts "  - #{type} | #{msg}"} unless config.silent?
            end
          end
          puts unless config.silent? || ( is_repo && messages.flatten.empty? )
        end
        all_valid
      end

      # It checks a spec for minor non fatal defects
      #
      # It returns a array of messages
      #
      def warnings_for_spec(spec, file, is_repo)
        license  = spec.license
        source   = spec.source
        text     = file.read
        warnings = []
        warnings << "The name of the spec should match the name of the file" unless path_matches_name?(file, spec)
        warnings << "Missing license[:type]" unless license && license[:type]
        warnings << "Github repositories should end in `.git'" if source && source[:git] =~ /github.com/ && source[:git] !~ /.*\.git/
        warnings << "The description should end with a dot" if spec.description && spec.description !~ /.*\./
        warnings << "The summary should end with a dot" if spec.summary !~ /.*\./
        warnings << "Missing license[:file] or [:text]" unless is_repo || license && (license[:file] || license[:text])
        warnings << "Comments must be deleted" if text =~ /^\w*#/
        #TODO: the previous ´is_repo' check is there only because at the time of 0.6.0rc1 it would be triggered in all specs
        warnings
      end

      def path_matches_name?(file, spec)
        file.basename.to_s == spec.name + '.podspec'
      end

      # It reads a podspec file and checks for strings corresponding
      # to a feature that are or will be deprecated
      #
      # It returns a array of messages
      #
      def deprecation_notices_for_spec(spec, file, is_repo)
        text = file.read
        deprecations = []
        deprecations << "`config.ios?' and `config.osx' will be removed in version 0.7" if text. =~ /config\..os?/
        deprecations << "Currently there is no known reason to use the `post_install' hook" if text. =~ /post_install/
        deprecations
      end

      # It creates a podfile in memory and builds a library containing
      # the pod for all available platfroms with xcodebuild.
      #
      # It returns a array of messages
      #
      def build_errors_for_spec(spec, file, is_repo)
        messages = []
        platform_names(spec).each do |platform_name|
          config.silent = true
          config.integrate_targets = false
          config.project_root = Pathname.pwd
          podfile = podfile_from_spec(spec, file, platform_name)
          Installer.new(podfile).install!

          config.silent = false
          output        = Dir.chdir('Pods') { `xcodebuild 2>&1` }
          clean_output  = proces_xcode_build_output(output).map {|l| "#{platform_name}: #{l}"}
          messages     += clean_output
        end
        messages
      end

      def podfile_from_spec(spec, file, platform_name)
        podfile = Pod::Podfile.new do
          platform platform_name
          dependency spec.name, :podspec => file.realpath.to_s
        end
      end

      def proces_xcode_build_output(output)
        output_by_line = output.split("\n")
        selected_lines = output_by_line.select do |l|
          l.include?('error')\
          || l.include?('warning') && !l.include?('warning generated.')\
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
      def file_errors_for_spec(spec, file, is_repo)
        Dir.chdir('Pods/' + spec.name ) do
          messages = []
          messages += check_spec_files_exists(spec, :source_files)
          messages += check_spec_files_exists(spec, :resources)
          spec.clean_paths.each do |pattern|
            messages << "clean_paths = '#{pattern}' -> did not match any file" if Pathname.pwd.glob(pattern).empty?
          end
          messages.compact
        end
      end

      def check_spec_files_exists(spec, accessor)
        result = []
        platform_names(spec).each do |platform_name|
          patterns = spec.send(accessor)[platform_name]
          unless patterns.empty?
            patterns.each do |pattern|
              result << "#{platform_name}: #{accessor} = '#{pattern}' -> did not match any file" if Pathname.pwd.glob(pattern).empty?
            end
          end
        end
        result
      end

      def platform_names(spec)
        spec.platform.name || [:ios, :osx]
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
