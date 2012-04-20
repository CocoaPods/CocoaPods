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

    $ pod spec create [NAME]
    $ pod spec create [https://github.com/USER/REPO]

      Creates a PodSpec, in the current working dir, called `NAME.podspec'.
      If a GitHub url is passed the spec is prepopulated.

    $ pod spec lint [NAME.podspec]

      Validates `NAME.podspec'. In case `NAME.podspec' is omitted, it defaults
      to `*.podspec' in the current working dir.}
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
        puts "\nSpecification created at #{data[:name]}.podspec\n".green
      end

      def lint
        name = @name_or_url
        file = name ? Pathname.new(name) : Pathname.pwd.glob('*.podspec').first
        spec = Specification.from_file(file)
        puts "\nThe #{spec.name} specification contains all the required attributes.".green if spec.validate!

        warnings = []
        warnings << 'The name of the specification should match the name of the podspec file' unless path_matches_name?(file, spec)
        warnings << 'Missing license[:type]'                    unless spec.license && spec.license[:type]
        warnings << 'Missing license[:file] or [:text]'         unless spec.license && (spec.license[:file] || spec.license[:text])
        warnings << "Github repositories should end in `.git'"  if spec.source[:git] =~ /github.com/ && spec.source[:git] !~ /.*\.git/
        warnings << "Github repositories should end in `.git'"  if spec.source[:git] =~ /github.com/ && spec.source[:git] !~ /.*\.git/
        warnings << "The description should end with a dot"     if spec.description && spec.description !~ /.*\./
        warnings << "The summary should end with a dot"         if spec.summary !~ /.*\./

        unless warnings.empty?
          puts "\n[!] The #{spec.name} specification raised the following warnings".yellow
          warnings.each { |warn| puts ' - '+ warn }
        end
        puts
      end

      private

      def path_matches_name?(path, spec)
        (path.dirname + "#{spec.name}.podspec").to_s == @name_or_url
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
