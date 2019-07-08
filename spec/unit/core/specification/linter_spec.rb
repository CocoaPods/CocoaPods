require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Specification::Linter do
    before do
      WebMock::API.stub_request(:head, /banana-corp.local/).to_return(:status => 200)
    end

    describe 'In general' do
      before do
        fixture_path = 'spec-repos/test_repo/Specs/BananaLib/1.0/BananaLib.podspec'
        @podspec_path = fixture(fixture_path)
      end

      it 'can be initialized with a specification' do
        spec = Specification.from_file(@podspec_path)
        @linter = Specification::Linter.new(spec)
        @linter.spec.name.should == 'BananaLib'
        @linter.file.should == @podspec_path
      end

      it 'can be initialized with a path' do
        @linter = Specification::Linter.new(@podspec_path)
        @linter.spec.name.should == 'BananaLib'
        @linter.file.should == @podspec_path
      end

      extend SpecHelper::TemporaryDirectory

      it 'catches specification load errors' do
        podspec = 'Pod::Spec.new do |s|; error; end'
        path = SpecHelper.temporary_directory + 'BananaLib.podspec'
        File.open(path, 'w') { |f| f.write(podspec) }
        lambda { Specification.from_file(path) }.should.raise Pod::DSLError
        lambda { Specification::Linter.new(path) }.should.not.raise
      end

      it 'includes an error indicating that the specification could not be loaded' do
        podspec = 'Pod::Spec.new do |s|; error; end'
        path = SpecHelper.temporary_directory + 'BananaLib.podspec'
        File.open(path, 'w') { |f| f.write(podspec) }
        linter = Specification::Linter.new(path)
        linter.lint
        results = linter.results
        results.count.should == 1
        results.first.message.should.match /spec.*could not be loaded/
        results.first.attribute_name.should.include?('spec')
      end

      before do
        fixture_path = 'spec-repos/test_repo/Specs/BananaLib/1.1/BananaLib.podspec'
        @podspec_path = fixture(fixture_path)
        @linter = Specification::Linter.new(@podspec_path)
      end

      it 'accepts a valid podspec' do
        valid = @linter.lint
        @linter.results.should.be.empty?
        valid.should.be.true
      end

      describe 'with a spec loaded from json' do
        before do
          fixture_path = 'spec-repos/test_repo/Specs/BananaLib/1.1/BananaLib.podspec'
          podspec_path = fixture(fixture_path)
          podspec = Pod::Specification.from_file(podspec_path)
          json = podspec.to_pretty_json
          podspec = Pod::Specification.from_string(json, podspec_path.sub_ext('.podspec.json'))
          @linter = Specification::Linter.new(podspec)
        end

        it 'accepts a valid podspec' do
          valid = @linter.lint
          @linter.results.should.be.empty?
          valid.should.be.true
        end
      end

      it 'compacts multi_platform attributes' do
        @linter.spec.platform = nil
        @linter.spec.source_files = '/Absolute'
        @linter.lint
        @linter.results.count.should == 1
        @linter.results.first.platforms.map(&:to_s).sort.should ==
          %w(ios osx tvos watchos)
      end

      before do
        @linter.spec.name = nil
        @linter.spec.summary = 'A short description of.'
        @linter.lint
      end

      it 'returns the results of the lint' do
        results = @linter.results.map { |r| r.type.to_s }.sort.uniq
        results.should == %w(error warning)
      end

      it 'returns the errors results of the lint' do
        @linter.errors.map(&:type).uniq.should == [:error]
      end

      it 'returns the warnings results of the lint' do
        @linter.warnings.map(&:type).should == [:warning]
      end
    end

    shared 'Linter' do
      before do
        @podspec_path = fixture(@fixture_path)
        @linter = Specification::Linter.new(@podspec_path)
        @spec = @linter.spec
        @results = nil
      end

      def results
        @linter.lint
        @results ||= @linter.results.map { |x| x }
      end

      def result_ignore(*values)
        results.reject! do |result|
          values.all? do |value|
            result.to_s.downcase.include?(value.downcase)
          end
        end
      end

      def result_should_include(*values)
        matched = results.select do |result|
          values.all? do |value|
            result.to_s.downcase.include?(value.downcase)
          end
        end

        matched.should.satisfy("Expected #{values.inspect} " \
                "but none of those results matched:\n" \
                "#{results.map(&:to_s)}") do |m|
          m.count > 0
        end

        matched.should.satisfy("Expected #{values.inspect} " \
                "found matches:\n"  \
                "#{matched.map(&:to_s)}\n" \
                "but unexpected results appeared:\n" \
                "#{(results - matched).map(&:to_s)}") do |m|
          m.count == results.count
        end
      end
    end

    #--------------------------------------#

    describe 'Root spec' do
      before do
        @fixture_path = 'spec-repos/test_repo/Specs/BananaLib/1.0/BananaLib.podspec'
      end

      behaves_like 'Linter'

      #------------------#

      it 'checks for unrecognized keys' do
        @spec.attributes_hash[:foo] = 'bar'
        result_should_include('foo', 'unrecognized')
      end

      it 'checks the type of the values of the attributes' do
        @spec.homepage = %w(Pod)
        result_should_include('homepage', 'unacceptable type')
      end

      it 'checks for unknown keys in the license' do
        @spec.license = { :name => 'MIT' }
        result_ignore('license', 'missing', 'type')
        result_should_include('license', 'unrecognized `name` key')
      end

      it 'checks that source is a hash' do
        @spec.source = '.'
        result_should_include('source', 'Unsupported type `String`, expected `Hash`')
      end

      it 'checks the source for unknown keys' do
        @spec.source = { :tig => 'www.example.com/repo.tig' }
        result_should_include('[keys]', 'Missing primary key for `source` attribute. The acceptable ones are: `git, hg, http, svn`.')
      end

      it 'checks the required attributes' do
        @spec.stubs(:name).returns(nil)
        result_should_include('name', 'required')
      end

      #------------------#

      it 'fails a specification whose name does not match the name of the `podspec` file' do
        @spec.stubs(:name).returns('another_name')
        result_should_include('name', 'match')
      end

      it 'fails a specification whose name contains whitespace' do
        @spec.name = 'bad name'
        result_ignore('name', 'match')
        result_should_include('name', 'whitespace')
      end

      it 'fails a specification whose name contains a slash' do
        @spec.name = 'BananaKit/BananaFruit'
        result_ignore('name', 'match')
        result_should_include('name', 'slash')
      end

      #------------------#

      it 'fails a specification whose authors are the default' do
        @spec.stubs(:authors).returns('YOUR NAME HERE' => 'YOUR EMAIL HERE')
        result_should_include('author', 'default')
      end

      it 'fails a specification whose authors are an empty hash' do
        @spec.stubs(:authors).returns({})
        result_should_include('author', 'required')
      end

      it 'fails a specification whose authors are an empty array' do
        @spec.stubs(:authors).returns([])
        result_should_include('author', 'required')
      end

      #------------------#

      it 'passes a specification whose module name is a valid C99 identifier' do
        @spec.stubs(:module_name).returns('_')
        @linter.lint
        @linter.results.count.should == 0
      end

      it 'fails a specification whose module name is not a valid C99 identifier' do
        @spec.stubs(:module_name).returns('20Three lol')
        result_should_include('module_name', 'C99 identifier')
      end

      #------------------#

      it 'passes a specification with a module map' do
        @spec.module_map = 'module.modulemap'
        @linter.lint
        @linter.results.count.should == 0
      end

      #------------------#

      it 'checks that the version has been specified' do
        @spec.stubs(:version).returns(Pod::Version.new(nil))
        result_should_include('version', 'required')
      end

      it 'checks the version is higher than 0' do
        @spec.stubs(:version).returns(Pod::Version.new('0'))
        result_should_include('version', '0')
      end

      it 'handles invalid version strings' do
        @spec.stubs(:version).raises('Bad version')
        result_ignore('attributes')
        result_should_include('version', 'Unable to validate due to exception: Bad version')
      end

      #------------------#

      it 'checks the summary length' do
        @spec.stubs(:summary).returns('sample ' * 100 + '.')
        @spec.stubs(:description).returns(nil)
        result_should_include('summary', 'short')
      end

      it 'checks the summary for the example value' do
        @spec.stubs(:summary).returns('A short description of.')
        result_should_include('summary', 'meaningful')
      end

      #------------------#

      it 'checks the test type value is correct' do
        podspec = 'Pod::Spec.new do |s|; s.test_spec do |ts|; ts.test_type = :unknown; end end'
        path = SpecHelper.temporary_directory + 'BananaLib.podspec'
        File.open(path, 'w') { |f| f.write(podspec) }
        linter = Specification::Linter.new(path)
        linter.lint
        results = linter.results
        test_type_error = results.find { |result| result.to_s.downcase.include?('test_type') }
        test_type_error.message.should.include?('The test type `unknown` is not supported.')
      end

      it 'checks the test type value is correct using a JSON podspec' do
        podspec = '{"testspecs":[{"name": "Tests","test_type": "unit","source_files": "Tests/**/*.{h,m}"}]}'
        path = SpecHelper.temporary_directory + 'BananaLib.podspec.json'
        File.open(path, 'w') { |f| f.write(podspec) }
        linter = Specification::Linter.new(path)
        linter.lint
        results = linter.results
        test_type_error = results.find { |result| result.to_s.downcase.include?('test_type') }
        test_type_error.should.be.nil
      end

      it 'checks the test type value is correctly set in a subspec using 1.3.0 JSON podspec' do
        podspec = '{"subspecs":[{"name": "Tests","test_type": "unit","source_files": "Tests/**/*.{h,m}"}]}'
        path = SpecHelper.temporary_directory + 'BananaLib.podspec.json'
        File.open(path, 'w') { |f| f.write(podspec) }
        linter = Specification::Linter.new(path)
        linter.lint
        results = linter.results
        test_type_error = results.find { |result| result.to_s.downcase.include?('test_type') }
        test_type_error.should.be.nil
      end

      #------------------#

      it 'fails a test spec with `requires_app_host = false` and `app_host_name` set' do
        @spec.test_specification = true
        @spec.requires_app_host = false
        @spec.app_host_name = 'BananaLib/App'
        result_ignore('must explicitly declare a dependency')
        result_should_include('app_host_name', 'requires_app_host')
      end

      it 'passes a test spec with `requires_app_host = true` and `app_host_name` set' do
        @spec.test_specification = true
        @spec.requires_app_host = true
        @spec.app_host_name = 'BananaLib/App'
        @spec.dependency 'BananaLib/App'
        @linter.lint
        @linter.results.should.be.empty?
      end

      it 'fails a test spec requiring an app host from a pod that isn\'t required' do
        @spec.test_specification = true
        @spec.requires_app_host = true
        @spec.app_host_name = 'Foo/App'
        result_should_include('app_host_name', 'Foo')
      end

      it 'passes a test spec requiring an app host from a pod that is listed as a dependency' do
        @spec.dependency 'Foo/App'
        @spec.test_specification = true
        @spec.requires_app_host = true
        @spec.app_host_name = 'Foo/App'
        @linter.lint
        @linter.results.should.be.empty?
      end

      #------------------#

      it 'checks if the description is not an empty string' do
        @spec.stubs(:description).returns('')
        result_should_include('description', 'empty')
      end

      it 'checks if the description is equal to the summary' do
        @spec.stubs(:description).returns(@linter.spec.summary)
        result_should_include('description', 'equal', 'summary')
      end

      it 'checks if the description is shorter than the summary' do
        @spec.stubs(:description).returns('sample.')
        result_should_include('description', 'shorter', 'summary')
      end

      it 'does not crash when there is a description but no summary' do
        @spec.stubs(:description).returns('sample.')
        @spec.stubs(:summary).returns(nil)
        lambda { @linter.lint }.should.not.raise
      end

      #------------------#

      it 'checks if the homepage has been changed from default' do
        @spec.stubs(:homepage).returns('http://EXAMPLE/test')
        result_should_include('homepage', 'default')
      end

      #------------------#

      it 'checks whether the license type' do
        @spec.stubs(:license).returns(:file => 'License')
        result_should_include('license', 'type')
      end

      it 'checks the license type for the sample value' do
        @spec.stubs(:license).returns(:type => '(example)')
        result_should_include('license', 'type')
      end

      it 'checks whether the license type is empty' do
        @spec.stubs(:license).returns(:type => ' ')
        result_should_include('license', 'type')
      end

      it 'checks whether the license file has an allowed extension' do
        @spec.stubs(:license).returns(:type => 'MIT', :file => 'MIT.txt')
        @linter.lint
        @linter.results.should.be.empty
      end

      it 'checks whether the license file has a disallowed extension' do
        @spec.stubs(:license).returns(:type => 'MIT', :file => 'MIT.pdf')
        result_should_include('license', 'file')
      end

      it 'allows license files without a file extension' do
        @spec.stubs(:license).returns(:type => 'MIT', :file => 'LICENSE')
        @linter.lint
        @linter.results.should.be.empty
      end

      #------------------#

      it 'allows a local git URL as source' do
        @spec.stubs(:source).returns(:git => 'file:///tmp/d20131009-82757-1tztajd', :tag => '1.0')
        @linter.lint
        @linter.results.should.be.empty
      end

      it 'checks for the example source' do
        @spec.stubs(:source).returns(:git => 'http://EXAMPLE.git', :tag => '1.0')
        result_should_include('source', 'example')
      end

      it 'checks that the commit is not specified as `HEAD`' do
        @spec.stubs(:version).returns(Version.new '0.0.1')
        @spec.stubs(:source).returns(:git => 'http://repo.git', :commit => 'HEAD')
        result_ignore('Git sources should specify a tag.')
        result_should_include('source', 'HEAD')
      end

      it 'checks that the version is included in the git tag when the version is a string' do
        @spec.stubs(:version).returns(Version.new '1.0.1')
        @spec.stubs(:source).returns(:git => 'http://repo.git', :tag => '1.0')
        result_should_include('git', 'version', 'tag')
      end

      it 'checks that the version is included in the git tag  when the version is a Version' do
        @spec.stubs(:version).returns(Version.new '1.0.1')
        @spec.stubs(:source).returns(:git => 'http://repo.git', :tag => (Version.new '1.0'))
        result_should_include('git', 'version', 'tag')
      end

      it 'checks that Github repositories use the `https` form (for compatibility)' do
        @spec.stubs(:source).returns(:git => 'http://github.com/repo.git', :tag => '1.0')
        result_should_include('Github', 'https')
      end

      it 'performs checks for Gist Github repositories' do
        @spec.stubs(:source).returns(:git => 'git://gist.github.com/2823399.git', :tag => '1.0')
        result_should_include('Github', 'https')
      end

      it 'checks that Github repositories do not use `www` (for compatibility)' do
        @spec.stubs(:source).returns(:git => 'https://www.github.com/repo.git', :tag => '1.0')
        result_should_include('Github', 'www')
      end

      it 'checks that Gist Github repositories do not use `www`' do
        @spec.stubs(:source).returns(:git => 'https://www.gist.github.com/2823399.git', :tag => '1.0')
        result_should_include('Github', 'www')
      end

      it 'checks that Github repositories end in .git (for compatibility)' do
        @spec.stubs(:source).returns(:git => 'https://github.com/repo', :tag => '1.0')
        result_should_include('Github', '.git')
        @linter.results.first.type.should == :warning
      end

      it 'does not warn for Github repositories with OAuth authentication' do
        @spec.stubs(:source).returns(:git => 'https://TOKEN:x-oauth-basic@github.com/COMPANY/REPO.git', :tag => '1.0')
        @linter.lint
        @linter.results.should.be.empty
      end

      it 'does not warn for local repositories with spaces' do
        @spec.stubs(:source).returns(:git => '/Users/kylef/Projects X', :tag => '1.0')
        @linter.lint
        @linter.results.should.be.empty
      end

      it 'warns for SSH repositories' do
        @spec.stubs(:source).returns(:git => 'git@bitbucket.org:kylef/test.git', :tag => '1.0')
        @linter.lint
        result_should_include('Git', 'SSH')
      end

      it 'warns for SSH repositories on Github' do
        @spec.stubs(:source).returns(:git => 'git@github.com:kylef/test.git', :tag => '1.0')
        result_should_include('Git', 'SSH')
      end

      it 'performs checks for Gist Github repositories' do
        @spec.stubs(:source).returns(:git => 'git://gist.github.com/2823399.git', :tag => '1.0')
        result_should_include('Github', 'https')
      end

      it 'checks the source of 0.0.1 specifications for a tag' do
        @spec.stubs(:version).returns(Version.new '0.0.1')
        @spec.stubs(:source).returns(:git => 'www.banana-empire.git')
        result_should_include('sources', 'specify a tag.')
      end

      it 'checks git sources for a tag' do
        @spec.stubs(:version).returns(Version.new '1.0.1')
        @spec.stubs(:source).returns(:git => 'www.banana-empire.git')
        result_should_include('sources', 'specify a tag.')
      end

      #------------------#

      it 'checks if the social_media_url has been changed from default' do
        @spec.stubs(:social_media_url).returns('https://twitter.com/EXAMPLE')
        result_should_include('social media URL', 'default')
      end

      #------------------#

      it 'checks script phases include the required keys' do
        @spec.script_phases = { :name => 'Hello World' }
        result_should_include('script_phases', 'Missing required shell script phase options `script` in script phase `Hello World`.')
      end

      it 'checks script phases that include unknown keys' do
        @spec.script_phases = { :name => 'Hello World', :script => 'echo "Hello World"', :unknown => 'unknown' }
        result_should_include('script_phases', 'Unrecognized option(s) `unknown` in script phase `Hello World`. ' \
          'Available options are `name, script, shell_path, input_files, output_files, input_file_lists, ' \
          'output_file_lists, show_env_vars_in_log, execution_position`.')
      end

      it 'checks script phases include a valid execution position value' do
        @spec.script_phases = { :name => 'Hello World', :script => 'echo "Hello World"', :execution_position => :unknown }
        result_should_include('script_phases', 'Invalid execution position value `unknown` in shell script `Hello World`. ' \
          'Available options are `before_compile, after_compile, any`.')
      end

      #------------------#

      it 'accepts valid scheme values' do
        @spec.scheme = { :launch_arguments => ['Arg1'], :environment_variables => { 'Key1' => 'Val1' } }
        @linter.lint
        @linter.results.should.be.empty
      end

      it 'checks scheme launch arguments key type' do
        @spec.scheme = { :launch_arguments => 'Arg1' }
        result_should_include('scheme', 'Expected an array for key `launch_arguments`.')
      end

      it 'checks scheme environment variables key type' do
        @spec.scheme = { :environment_variables => [] }
        result_should_include('scheme', 'Expected a hash for key `environment_variables`.')
      end

      #------------------#

      it 'accepts valid frameworks' do
        @spec.frameworks = %w(AddressBook Audio-Frameworks)
        @linter.lint
        results = @linter.results
        results.should.be.empty
      end

      it 'checks that frameworks do not end with a .framework extension' do
        @spec.frameworks = %w(AddressBook.framework QuartzCore.framework)
        result_should_include('framework', 'name')
      end

      it 'checks that frameworks do not include unwanted characters' do
        @spec.frameworks = ['AddressBook, QuartzCore']
        result_should_include('framework', 'name')
      end

      it 'checks that weak frameworks do not end with a .framework extension' do
        @spec.weak_frameworks = %w(AddressBook.framework QuartzCore.framework)
        result_should_include('weak framework', 'name')
      end

      it 'checks that weak frameworks do not include unwanted characters' do
        @spec.weak_frameworks = ['AddressBook, QuartzCore']
        result_should_include('weak framework', 'name')
      end

      #------------------#

      it 'accepts valid libraries' do
        @spec.libraries = %w(
          stdc++
          z.1
          curl.OSX
          stdc++.6.0.9
          Geoloqi-$(CONFIGURATION)
        )
        @linter.lint
        results = @linter.results
        results.should.be.empty
      end

      it 'checks that libraries do not end with a .a extension' do
        @spec.libraries = %w(z.a)
        result_should_include('should not include the extension', 'z.a',
                              'libraries')
      end

      it 'checks that libraries do not end with a .dylib extension' do
        @spec.libraries = %w(ssl.dylib)
        result_should_include('should not include the extension', 'ssl.dylib',
                              'libraries')
      end

      it 'checks that libraries do not begin with lib' do
        @spec.libraries = %w(libz)
        result_should_include('should omit the `lib` prefix', 'libz',
                              'libraries')
      end

      it 'checks that libraries do not contain unwanted characters' do
        @spec.libraries = ['ssl, z']
        result_should_include('should not include comas', 'ssl, z',
                              'libraries')
      end

      it 'checks that a spec is not deprecated in favor of itself' do
        @spec.deprecated_in_favor_of = @spec.name
        result_should_include('a spec cannot be', 'deprecated_in_favor_of')
      end

      it 'does not warn when a spec is deprecated in favor of a different spec' do
        @spec.deprecated_in_favor_of = @spec.name + '_other'
        @linter.lint
        results = @linter.results
        results.should.be.empty
      end

      #------------------#

      it 'checks if the compiler flags disable warnings' do
        @spec.compiler_flags = '-some_flag', '-another -Wno_flags'
        result_should_include('warnings', 'disabled', 'compiler_flags')
      end
    end

    #--------------------------------------#

    describe 'Subspec' do
      before do
        @fixture_path = 'lint_podspec/RestKit.podspec'
      end

      behaves_like 'Linter'

      before do
        @subspec = @spec.subspecs.first
      end

      it 'fails a subspec whose name contains whitespace' do
        @subspec.name = 'bad name'
        result_should_include('name', 'whitespace')
      end

      it 'fails a subspec whose name begins with a `.`' do
        @subspec.name = '.badname'
        result_should_include('name', 'period')
      end

      it 'fails a specification whose name contains a slash' do
        @subspec.name = 'BananaKit/BananaFruit'
        result_should_include('name', 'slash')
      end

      #------------------#

      it 'fails if a subspec specifies a scheme' do
        @subspec.scheme = { :launch_arguments => ['Arg1'] }
        result_should_include('scheme', 'Scheme configuration is not currently supported for subspecs.')
      end

      #------------------#

      it 'fails a specification with a subspec with a module map' do
        @subspec.module_map = 'subspec.modulemap'
        result_should_include('module_map', 'can\'t set', 'for subspecs')
      end

      #------------------#

      it 'fails a specification with a subspec with default subspecs' do
        @subspec.default_subspecs = 'Spec'
        result_should_include('default_subspecs', 'can\'t set', 'for subspecs')
      end

      #------------------#

      it 'fails if a subspec specifies info_plist' do
        @subspec.info_plist = { 'SOME_VAR' => 'SOME_VALUE' }
        result_should_include('info_plist', 'Info.plist configuration is not currently supported for subspecs.')
      end
    end
  end
end
