module Pod
  class Command
    class Spec < Command
      def self.banner
%{Managing PodSpec files:

    $ pod spec create NAME

      Creates a PodSpec, in the current working dir, called `NAME.podspec'.

    $ pod spec lint NAME.podspec

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
        author = `git config --get user.name`.strip
        email = `git config --get user.email`.strip
        spec = <<-SPEC.gsub(/^          /, '')
          #
          # Be sure to run `pod spec lint #{@name}.podspec' to ensure this is a
          # valid spec.
          #
          # Remove all comments before submitting the spec.
          #
          Pod::Spec.new do |s|
            s.name     = '#{@name}'
            s.version  = '1.0.0'
            s.summary  = 'A short description of #{@name}.'
            s.homepage = 'http://EXAMPLE/#{@name}'
            s.author   = { '#{author}' => '#{email}' }

            # Specify the location from where the source should be retreived.
            #
            s.source   = { :git => 'http://EXAMPLE/#{@name}.git', :tag => '1.0.0' }
            # s.source   = { :svn => 'http://EXAMPLE/#{@name}/tags/1.0.0' }
            # s.source   = { :hg  => 'http://EXAMPLE/#{@name}', :revision => '1.0.0' }

            s.description = 'An optional longer description of #{@name}.'

            # If available specify the documentation sources.
            # :html       The online link for the documentation.
            # :atom       The atom link of the Xcode 4 compatible documentation set.
            # :appledoc   If the pod uses appledoc specify the options. The command
            #             will be run on the files specified in s.source_file.
            #
            s.documentation = {
            #  :html => 'http://EXAMPLE/#{@name}/documentation',
            #  :atom => 'http://EXAMPLE/#{@name}/com.company.#{@name}.atom',
            #  :appledoc => ['--project-name', '#{@name}',
            #     '--project-company', '"Company Name"',
            #     '--company-id', 'com.company',
            #     '--output', './doc',
            #     '--ignore', 'Common',
            #     '--ignore', '.m'] 
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
          end
        SPEC
        (Pathname.pwd + "#{@name}.podspec").open('w') { |f| f << spec }
      end

      def lint
        file = @name ? Pathname.new(@name) : Pathname.pwd.glob('*.podspec').first
        spec = Specification.from_file(file)
        puts "This pod specification contains all required attributes." if spec.validate!
      end
    end
  end
end
