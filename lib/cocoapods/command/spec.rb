module Pod
  class Command
    class Spec < Command
      def self.banner
%{Managing PodSpec files:

    $ pod help spec

      pod spec create NAME
        Creates a PodSpec, in the current working dir, called `NAME.podspec'.

      pod spec lint NAME.podspec
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
          Pod::Spec.new do
            name     '#{@name}'
            version  '1.0.0'
            summary  'A short description of #{@name}.'
            homepage 'http://example.com/#{@name}'
            author   '#{author}' => '#{email}'
            source   :git => 'http://example.com/#{@name}.git',
                     :tag => '1.0.0'

            description 'An optional longer description of #{@name}.'

            # A list of file patterns. If the pattern is a directory then the path will
            # automatically have '*.{h,m,mm,c,cpp' appended.
            source_files 'Classes', 'Classes/**/*.{h,m}'

            xcconfig 'OTHER_LDFLAGS' => '-framework SomeRequiredFramework'

            dependency 'SomeLibraryThat#{@name}DependsOn', '>= 1.0.0'
          end
        SPEC
        (Pathname.pwd + "#{@name}.podspec").open('w') { |f| f << spec }
      end

      def lint
        file = @name ? Pathname.new(@name) : Pathname.pwd.glob('*.podspec').first
        spec = Specification.from_podspec(file)
        spec.validate!
      end
    end
  end
end
