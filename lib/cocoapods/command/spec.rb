require 'net/https'
require 'uri'
require 'json'
require 'awesome_print'

module Pod
  class Command
    class Spec < Command
      def self.banner
        %{Managing PodSpec files:

    $ pod spec create [NAME]
    $ pod spec create [https://github.com/user/repo]

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
        @action, @name = args.first(2)
      end

      def run
        send @action
      end

      def create
        spec = is_git_hub ? github_spec_doc : spec_doc
        (Pathname.pwd + "#{@name}.podspec").open('w') { |f| f << spec }
      end

      def lint
        file = @name ? Pathname.new(@name) : Pathname.pwd.glob('*.podspec').first
        spec = Specification.from_file(file)
        puts "\nThe #{spec.name} specification contains all the required attributes.".green if spec.validate!

        warnings = []
        warnings << 'The name of the specificaiton should match the name of the podspec file' if spec.name + '.podspec' != @name
        warnings << 'Missing license[:type]' unless spec.license && spec.license[:type]
        warnings << 'Missing license[:file] or [:text]' unless spec.license && (spec.license[:file] || spec.license[:text])
        warnings << "Github repositories should end in `.git'" if spec.source[:git] =~ /github.com/ && spec.source[:git] !~ /.*\.git/
        warnings << "Github repositories should end in `.git'" if spec.source[:git] =~ /github.com/ && spec.source[:git] !~ /.*\.git/
        warnings << "The description should end with a dot"    if spec.description &&  spec.description !~ /.*\./
        warnings << "The summary should end with a dot"        if spec.summary !~ /.*\./
        unless warnings.empty?
          puts "\n[!] The #{spec.name} specification raised the following warnings".yellow
          warnings.each { |warn| puts ' - '+ warn }
        end
        puts
      end

      private

      def is_git_hub
        @name =~ /https:\/\/github.com\/.*\/.*/
      end

      def find_github_info
        full, user, repo = *(@name.match /https:\/\/github.com\/(.*)\/(.*)/).to_a
        user_data = fetch_request("users/#{user}")
        repo_data = fetch_request("repos/#{user}/#{repo}")
        tags_data = fetch_request("repos/#{user}/#{repo}/tags")
        [user_data, repo_data, tags_data]
      end

      def fetch_request(request_url)
        uri               = URI.parse("https://api.github.com/#{request_url}")
        http              = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl      = true
        http.verify_mode  = OpenSSL::SSL::VERIFY_NONE
        request           = Net::HTTP::Get.new(uri.request_uri)
        response          = http.request(request)
        JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
      end

      def find_suggested_tag(tags_data)
        tags = tags_data.map {|hash| hash["name"] }
        versions = tags.reject {|t| t !~ /[0-9]+\.[0-9]+\.?[0-9]*/ }
        versions.sort.last || '0.0.1'
      end

      def version_from_tag(tag)
        tag.match /[0-9]+\.[0-9]+\.?[0-9]*/
      end

      def github_spec_doc
        user_data, repo_data, tags_data = find_github_info
        tag = find_suggested_tag(tags_data)
        version = version_from_tag(tag)

        @name = repo_data["name"]
        spec = <<-SPEC.gsub(/^          /, '')
          #
          # Be sure to run `pod spec lint #{@name}.podspec' to ensure this is a
          # valid spec.
          #
          # Remove all comments before submitting the spec.
          #
          Pod::Spec.new do |s|

          # ――― REQUIRED ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

            s.name     = '#{@name}'
            s.version  = '#{version}'
            s.summary  = '#{repo_data["description"].gsub(/[']/, '\\\\\'')}'
            s.homepage = '#{repo_data["homepage"] != "" ? repo_data["homepage"] : repo_data["html_url"]}'
            s.source   = { :git => '#{repo_data["clone_url"]}', :tag => '#{tag}' }
            s.author   = { '#{user_data["name"]}' => '#{user_data["email"]}' }
            # s.author   = { '#{user_data["name"]}' => '#{user_data["email"]}', 'other author' => 'and email address' }

            # Specify the license of the pod.
            # :type       The type of the license.
            # :file       The file containing the license of the pod.
            # :range      If a dedicated license file is not available specify a file
            #             that contains the license and the range of the lines
            #             containing the license.
            # :text       If the license is not available in any of the files it should be
            #             included here.
            s.license  = {
              :type => 'MIT',
              :file => 'LICENSE',
            #  :range => 1..15,
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

          # ――― OPTIONAL ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

            s.description = 'An optional longer description of #{@name}.'

            # If this Pod runs only on iOS or OS X, then specify that with one of
            # these, or none if it runs on both platforms.
            #
            # s.platform = :ios
            # s.platform = :osx

            # A list of resources included with the Pod. These are copied into the
            # target bundle with a build phase script.
            #
            # Also allows the use of the FileList class like `source_files does.
            #
            # s.resource = "icon.png"
            # s.resources = "Resources/*.png"

            # A list of paths to remove after installing the Pod without the
            # `--no-clean' option. These can be examples, docs, and any other type
            # of files that are not needed to build the Pod.
            #
            # *NOTE*: Never remove license and README files.
            #
            # Also allows the use of the FileList class like `source_files does.
            #
            # s.clean_path = "examples"
            # s.clean_paths = "examples", "doc"

            # Specify a list of frameworks that the application needs to link
            # against for this Pod to work.
            #
            # s.framework = 'SomeFramework'
            # s.frameworks = 'SomeFramework', 'AnotherFramework'

            # Specify a list of libraries that the application needs to link
            # against for this Pod to work.
            #
            # s.library = 'iconv'
            # s.libraries = 'iconv', 'xml2'

            # If this Pod uses ARC, specify it like so.
            #
            # s.requires_arc = true

            # Finally, specify any Pods that this Pod depends on.
            #
            # s.dependency 'JSONKit', '~> 1.4'
            #
            # ――― EXTRA ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

            # If you need to specify any other build settings, add them to the
            # xcconfig hash.
            #
            # s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

            # If available specify the documentation homepage.
            # :html       The online link for the documentation.
            # :appledoc   Ammend the default appledoc options used
            #             by cocoapods if needed.
            #
            # s.documentation = {
            #  :html => 'http://EXAMPLE/#{@name}/documentation',
            #  :appledoc => [
            #     '--project-name', '#{@name}',
            #     '--project-company', 'Company Name',
            #     '--docset-copyright', copyright,
            #     '--ignore', 'Common',
            #     '--index-desc', 'readme.markdown',
            #     '--no-keep-undocumented-objects',
            #     '--no-keep-undocumented-members',
            #     ]
            # }

          end
        SPEC
      end

      def spec_doc
        name = @name
        author = `git config --get user.name`.strip
        email = `git config --get user.email`.strip
        spec = <<-SPEC.gsub(/^          /, '')
          #
          # Be sure to run `pod spec lint #{name}.podspec' to ensure this is a
          # valid spec.
          #
          # Remove all comments before submitting the spec.
          #
          Pod::Spec.new do |s|
            s.name     = '#{name}'
            s.version  = '1.0.0'
            s.summary  = 'A short description of #{name}.'
            s.homepage = 'http://EXAMPLE/#{name}'

            # Specify the authors of the library, with email addresses. You can often find
            # the email addresses of the authors by using the SCM log. E.g. $ git log
            #
            s.author   = { '#{author}' => '#{email}', 'other author' => 'and email address' }
            # If absolutely no email addresses are available, then you can use this form instead.
            #
            # s.author   = '#{author}', 'other author'

            # Specify the location from where the source should be retreived.
            #
            s.source   = { :git => 'http://EXAMPLE/#{name}.git', :tag => '1.0.0' }
            # s.source   = { :svn => 'http://EXAMPLE/#{name}/tags/1.0.0' }
            # s.source   = { :hg  => 'http://EXAMPLE/#{name}', :revision => '1.0.0' }

            s.description = 'An optional longer description of #{name}.'

            # If available specify the documentation homepage.
            # :html       The online link for the documentation.
            # :appledoc   Ammend the default appledoc options used
            #             by cocoapods if needed.
            #
            s.documentation = {
            #  :html => 'http://EXAMPLE/#{name}/documentation',
            #  :appledoc => [
            #     '--project-name', '#{name}',
            #     '--project-company', 'Company Name',
            #     '--docset-copyright', copyright,
            #     '--ignore', 'Common',
            #     '--index-desc', 'readme.markdown',
            #     '--no-keep-undocumented-objects',
            #     '--no-keep-undocumented-members',
            #     ]
            }

            # Specify the license of the pod.
            # :type       The type of the license.
            # :file       The file containing the license of the pod.
            # :range      If a dedicated license file is not available specify a file
            #             that contains the license and the range of the lines
            #             containing the license.
            # :text       If the license is not available in any of the files it should be
            #             included here.
            s.license  = {
              :type => 'MIT',
              :file => 'LICENSE',
            #  :range => 1..15,
            #  :text => 'Permission is hereby granted ...'
            }

            # If this Pod runs only on iOS or OS X, then specify that with one of
            # these, or none if it runs on both platforms.
            #
            # s.platform = :ios
            # s.platform = :osx

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
            # s.resource = "icon.png"
            # s.resources = "Resources/*.png"

            # A list of paths to remove after installing the Pod without the
            # `--no-clean' option. These can be examples, docs, and any other type
            # of files that are not needed to build the Pod.
            #
            # *NOTE*: Never remove license and README files.
            #
            # Also allows the use of the FileList class like `source_files does.
            #
            # s.clean_path = "examples"
            # s.clean_paths = "examples", "doc"

            # Specify a list of frameworks that the application needs to link
            # against for this Pod to work.
            #
            # s.framework = 'SomeFramework'
            # s.frameworks = 'SomeFramework', 'AnotherFramework'

            # Specify a list of libraries that the application needs to link
            # against for this Pod to work.
            #
            # s.library = 'iconv'
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
        SPEC
      end
    end
  end
end
