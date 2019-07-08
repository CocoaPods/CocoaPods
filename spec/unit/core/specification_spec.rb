require File.expand_path('../spec_helper', __FILE__)

module Pod
  describe Specification do
    describe 'In general' do
      before do
        @spec = Spec.new do |s|
          s.name = 'Pod'
          s.version = '1.0'
          s.subspec 'Subspec' do |_sp|
          end
        end
        @subspec = @spec.subspecs.first
      end

      it 'returns the parent' do
        @subspec.parent.should == @spec
      end

      it 'returns the attributes hash' do
        @spec.attributes_hash.should == { 'name' => 'Pod', 'version' => '1.0' }
        @subspec.attributes_hash.should == { 'name' => 'Subspec' }
      end

      it 'returns the subspecs' do
        @spec.subspecs.should == [@subspec]
      end

      it 'allows dup-ing' do
        dup = @spec.dup
        dup.subspecs.first.parent.should.equal? dup
      end

      it 'returns whether it is equal to another specification' do
        @spec.should == @spec
      end

      it 'is not equal to another specification if the name is different' do
        @spec.should.not == Spec.new do |s|
          s.name = 'Seed'
          s.version = '1.0'
        end
      end

      it 'is not equal to another specification if the version if different' do
        @spec.should.not == Spec.new do |s|
          s.name = 'Pod'
          s.version = '2.0'
        end
      end

      it 'is equal to another if the name and the version match regardless of the attributes' do
        @spec.should == Spec.new do |s|
          s.name = 'Pod'
          s.version = '1.0'
          s.source_files = 'Classes'
        end
      end

      it 'provides support for Array#uniq' do
        spec_1 = Spec.new do |s|
          s.name = 'Pod'
          s.version = '1.0'
        end
        spec_2 = Spec.new do |s|
          s.name = 'Pod'
          s.version = '1.0'
        end
        [spec_1, spec_2].uniq.count.should == 1
      end

      it 'provides support for being used as a the key of a Hash' do
        spec_1 = Spec.new do |s|
          s.name = 'Pod'
          s.version = '1.0'
        end
        spec_2 = Spec.new do |s|
          s.name = 'Pod'
          s.version = '1.0'
        end
        hash = {}
        hash[spec_1] = 'VALUE_1'
        hash[spec_2] = 'VALUE_2'
        hash[spec_1].should == 'VALUE_2'
      end

      it 'strips newlines from versions' do
        spec = Spec.new do |s|
          s.name = 'Pod'
          s.version = "1.2.0\n"
        end

        spec.to_hash['version'].should == '1.2.0'
      end

      it 'resets hash value when name changes' do
        @spec.hash_value.should.be.nil?
        original_hash = @spec.hash
        @spec.hash_value.should.not.be.nil?
        @spec.name = 'NewPodName'
        @spec.hash_value.should.be.nil?
        new_hash = @spec.hash
        original_hash.should != new_hash
      end

      it 'resets hash value when version changes' do
        @spec.hash_value.should.be.nil?
        original_hash = @spec.hash
        @spec.hash_value.should.not.be.nil?
        @spec.version = '1.1'
        @spec.hash_value.should.be.nil?
        new_hash = @spec.hash
        original_hash.should != new_hash
      end

      describe '#to_s' do
        it 'produces a string representation suitable for UI output.' do
          @spec.to_s.should == 'Pod (1.0)'
        end

        it 'handles invalid version strings' do
          @spec.version = '{SOME_VERSION}'
          @spec.to_s.should == 'Pod ({SOME_VERSION})'
        end

        it 'includes the version in subspecs' do
          @subspec.to_s.should == 'Pod/Subspec (1.0)'
        end

        it 'includes malformed versions in subspecs' do
          @spec.version = '{SOME_VERSION}'
          @subspec.to_s.should == 'Pod/Subspec ({SOME_VERSION})'
        end
      end

      it 'handles the case where no version is available in the string representation' do
        spec_1 = Spec.new { |s| s.name = 'Pod' }
        spec_1.to_s.should == 'Pod'
      end

      it 'handles the case where no name is available in the string representation' do
        spec_1 = Spec.new
        spec_1.to_s.should == 'No-name'
      end

      it 'returns any empty array without any script phases' do
        spec = @spec.dup
        spec.script_phases.should == []
      end

      it 'returns the script phases with keys converted to symbols' do
        spec = @spec.dup
        spec.script_phase = [{ 'name' => 'Hello World', 'script' => 'echo "Hello World"', 'execution_position' => :before_compile }]
        spec.script_phases.should == [{ :name => 'Hello World', :script => 'echo "Hello World"', :execution_position => :before_compile }]
      end

      it 'returns the script phases with default execution position' do
        spec = @spec.dup
        spec.script_phase = [{ 'name' => 'Hello World', 'script' => 'echo "Hello World"' }]
        spec.script_phases.should == [{ :name => 'Hello World', :script => 'echo "Hello World"', :execution_position => :any }]
      end

      describe '#validate_cocoapods_version' do
        it 'passes when none is specified' do
          spec_1 = Specification.new
          should.not.raise { spec_1.validate_cocoapods_version }
        end

        it 'passes when the requirement is satisfied' do
          spec_1 = Specification.new { |s| s.cocoapods_version = '>= 0.1.0' }
          should.not.raise { spec_1.validate_cocoapods_version }
        end

        it 'fails when the requirement is not satisfied' do
          spec_1 = Specification.new { |s| s.cocoapods_version = '= 999999.0.0' }
          should.raise(Informative) { spec_1.validate_cocoapods_version }.message.
            should.match /CocoaPods version/
        end
      end

      describe '::name_and_version_from_string' do
        it 'returns the name and the version of a Specification from its #to_s output' do
          name, version = Specification.name_and_version_from_string('libPusher (1.0)')
          name.should == 'libPusher'
          version.should == Version.new('1.0')
        end

        it 'takes into account the full name of the subspec returning the name and the version' do
          string = 'RestKit/JSON (1.0)'
          name = Specification.name_and_version_from_string(string).first
          name.should == 'RestKit/JSON'
        end

        it 'handles names without version' do
          string = 'RestKit/JSON'
          name, version = Specification.name_and_version_from_string(string)
          name.should == 'RestKit/JSON'
          version.version.should.be.empty?
        end

        it 'handles names with a space without version' do
          string = 'RestKit/Subspec JSON'
          name, version = Specification.name_and_version_from_string(string)
          name.should == 'RestKit/Subspec JSON'
          version.version.should.be.empty?
        end

        it 'handles names with special characters without version' do
          string = 'RestKit_-+JSON'
          name, version = Specification.name_and_version_from_string(string)
          name.should == 'RestKit_-+JSON'
          version.version.should.be.empty?
        end

        it 'handles names with a space with version' do
          string = 'RestKit/Subspec JSON (1.0)'
          name, version = Specification.name_and_version_from_string(string)
          name.should == 'RestKit/Subspec JSON'
          version.version.should == '1.0'
        end

        it 'handles names with special characters with version' do
          string = 'RestKit_-+JSON (1.0)'
          name, version = Specification.name_and_version_from_string(string)
          name.should == 'RestKit_-+JSON'
          version.version.should == '1.0'
        end

        it 'raises if an invalid string representation is provided' do
          should.raise Informative do
            Specification.name_and_version_from_string('missing_version ()')
          end.message.should.match /Invalid string representation/
        end
      end

      describe '::root_name' do
        it 'returns the root name of a given specification name' do
          Specification.root_name('Pod').should == 'Pod'
          Specification.root_name('Pod/Subspec').should == 'Pod'
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Hierarchy' do
      before do
        @spec = Spec.new do |s|
          s.name = 'Pod'
          s.subspec 'Subspec' do |_sp|
          end
          s.test_spec do |_tsp|
          end
          s.app_spec do |_asp|
          end
        end
        @subspec = @spec.subspecs.first
        @test_subspec = @spec.test_specs.first
        @app_subspec = @spec.app_specs.first
      end

      it 'returns the root spec' do
        @spec.root.should == @spec
        @subspec.root.should == @spec
        @test_subspec.root.should == @spec
        @app_subspec.root.should == @spec
      end

      it 'returns whether it is a root spec' do
        @spec.root?.should.be.true
        @subspec.root?.should.be.false
        @test_subspec.root?.should.be.false
        @app_subspec.root?.should.be.false
      end

      it 'returns whether it is a subspec' do
        @spec.subspec?.should.be.false
        @subspec.subspec?.should.be.true
        @test_subspec.subspec?.should.be.true
        @app_subspec.subspec?.should.be.true
      end

      it 'returns whether it is a library_specification' do
        @spec.library_specification?.should.be.true
        @subspec.library_specification?.should.be.true
        @test_subspec.library_specification?.should.be.false
        @app_subspec.library_specification?.should.be.false
      end

      it 'returns whether it is a non_library_specification' do
        @spec.non_library_specification?.should.be.false
        @subspec.non_library_specification?.should.be.false
        @test_subspec.non_library_specification?.should.be.true
        @app_subspec.non_library_specification?.should.be.true
      end

      it 'returns whether it is a test_specification' do
        @spec.test_specification?.should.be.false
        @subspec.test_specification?.should.be.false
        @test_subspec.test_specification?.should.be.true
        @app_subspec.test_specification?.should.be.false
      end

      it 'returns whether it is a app_specification' do
        @spec.app_specification?.should.be.false
        @subspec.app_specification?.should.be.false
        @test_subspec.app_specification?.should.be.false
        @app_subspec.app_specification?.should.be.true
      end

      it 'returns the correct spec_type' do
        @spec.spec_type.should == :library
        @subspec.spec_type.should == :library
        @test_subspec.spec_type.should == :test
        @app_subspec.spec_type.should == :app
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Dependencies' do
      before do
        @spec = Spec.new do |s|
          s.name = 'Pod'
          s.version = '1.0'
          s.dependency 'AFNetworking'
          s.osx.dependency 'MagicalRecord'
          s.subspec 'Subspec' do |sp|
            sp.dependency 'libPusher'
            sp.subspec 'Subsubspec' do |_ssp|
            end
          end
          s.subspec 'SubspecOSX' do |sp|
            sp.platform = :osx
          end
          s.subspec 'SubspeciOS' do |sp|
            sp.platform = :ios
          end
        end
        @subspec = @spec.subspecs[0]
        @subspec_osx = @spec.subspecs[1]
        @subspec_ios = @spec.subspecs[2]
        @subsubspec = @subspec.subspecs.first
      end

      it 'returns the recursive subspecs' do
        @spec.recursive_subspecs.sort_by(&:name).should == [@subspec, @subsubspec, @subspec_osx, @subspec_ios]
      end

      it 'returns a subspec given the absolute name' do
        @spec.subspec_by_name('Pod/Subspec').should == @subspec
        @spec.subspec_by_name('Pod/Subspec/Subsubspec').should == @subsubspec
      end

      it "doesn't return the test subspec given its name" do
        @spec = Spec.new do |s|
          s.name = 'Pod'
          s.version = '1.0'
          s.dependency 'AFNetworking'
          s.osx.dependency 'MagicalRecord'
          s.test_spec {}
        end
        @spec.subspec_by_name('Pod/Tests', false).should. nil?
      end

      it "does return the test subspec given it's name when including test subspecs" do
        @spec = Spec.new do |s|
          s.name = 'Pod'
          s.version = '1.0'
          s.dependency 'AFNetworking'
          s.osx.dependency 'MagicalRecord'
          s.test_spec {}
        end
        test_spec = @spec.test_specs.first
        @spec.subspec_by_name('Pod/Tests', false, true).should == test_spec
      end

      it "doesn't return the app subspec given its name" do
        @spec = Spec.new do |s|
          s.name = 'Pod'
          s.version = '1.0'
          s.dependency 'AFNetworking'
          s.osx.dependency 'MagicalRecord'
          s.app_spec {}
        end
        @spec.subspec_by_name('Pod/App', false).should. nil?
      end

      it "does return the app subspec given it's name when including app subspecs" do
        @spec = Spec.new do |s|
          s.name = 'Pod'
          s.version = '1.0'
          s.dependency 'AFNetworking'
          s.osx.dependency 'MagicalRecord'
          s.app_spec {}
        end
        app_spec = @spec.app_specs.first
        @spec.subspec_by_name('Pod/App', false, true).should == app_spec
      end

      it 'returns a subspec given the relative name' do
        @subspec.subspec_by_name('Subspec/Subsubspec').should == @subsubspec
      end

      it "raises if it can't find a subspec with the given name" do
        lambda { @spec.subspec_by_name('Pod/Nonexistent') }.should.raise Informative
      end

      it 'raises if there is a base name case mis-match' do
        lambda { @spec.subspec_by_name('pod') }.should.raise Informative
      end

      it "returns if it can't find a subspec with the given name and raise_if_missing is false" do
        @spec.subspec_by_name('Pod/Nonexistent', false).should.be.nil?
      end

      it "returns if it can't find a deeply nested subspec with the given name and raise_if_missing is false" do
        @spec.subspec_by_name('Pod/Subspec/Subsubspec/Missing', false).should.be.nil?
      end

      it 'returns the default subspecs' do
        spec = @spec.dup
        spec.default_subspecs = 'Subspec1', 'Subspec2'
        spec.default_subspecs.should == %w(Subspec1 Subspec2)
      end

      it 'supports the specification of the default subspecs as a string' do
        spec = @spec.dup
        spec.default_subspecs = 'Subspec1'
        spec.default_subspecs.should == %w(Subspec1)
      end

      it 'returns the dependencies on its subspecs' do
        @spec.subspec_dependencies.sort.should == [
          Dependency.new('Pod/Subspec', '1.0'),
          Dependency.new('Pod/SubspecOSX', '1.0'),
          Dependency.new('Pod/SubspeciOS', '1.0')]
      end

      it 'returns the dependencies on its subspecs for a given platform' do
        @spec.subspec_dependencies(:ios).should == [
          Dependency.new('Pod/Subspec', '1.0'),
          Dependency.new('Pod/SubspeciOS', '1.0'),
        ]
      end

      it 'returns a dependency on a default subspecs if it is specified' do
        @spec.default_subspecs = 'Subspec', 'SubspeciOS'
        @spec.subspec_dependencies.should == [
          Dependency.new('Pod/Subspec', '1.0'),
          Dependency.new('Pod/SubspeciOS', '1.0'),
        ]
      end

      it 'excludes the test subspec from the subspec dependencies' do
        @spec.test_spec {}
        @spec.subspec_dependencies.sort.should == [
          Dependency.new('Pod/Subspec', '1.0'),
          Dependency.new('Pod/SubspecOSX', '1.0'),
          Dependency.new('Pod/SubspeciOS', '1.0')]
      end

      it 'excludes the app subspec from the subspec dependencies' do
        @spec.app_spec {}
        @spec.subspec_dependencies.sort.should == [
          Dependency.new('Pod/Subspec', '1.0'),
          Dependency.new('Pod/SubspecOSX', '1.0'),
          Dependency.new('Pod/SubspeciOS', '1.0')]
      end

      it 'returns all the dependencies' do
        @spec.dependencies.sort.should == [
          Dependency.new('AFNetworking'),
          Dependency.new('MagicalRecord')]
      end

      it 'returns the test spec dependencies' do
        test_spec = @spec.test_spec { |s| s.dependency 'OCMock' }
        test_spec.dependencies.sort.should == [
          Dependency.new('AFNetworking'),
          Dependency.new('MagicalRecord'),
          Dependency.new('OCMock'),
        ]
      end

      it 'returns the app spec dependencies' do
        app_spec = @spec.app_spec { |s| s.dependency 'OCMock' }
        app_spec.dependencies.sort.should == [
          Dependency.new('AFNetworking'),
          Dependency.new('MagicalRecord'),
          Dependency.new('OCMock'),
        ]
      end

      it 'returns the dependencies given the platform' do
        @spec.dependencies(:ios).sort.should == [Dependency.new('AFNetworking')]
      end

      it 'inherits the dependencies of the parent' do
        @subsubspec.dependencies(:ios).sort.should == [Dependency.new('AFNetworking'), Dependency.new('libPusher')]
      end

      it 'returns all the dependencies including the ones on subspecs given a platform' do
        @spec.all_dependencies.sort.should == [
          Dependency.new('AFNetworking'),
          Dependency.new('MagicalRecord'),
          Dependency.new('Pod/Subspec', '1.0'),
          Dependency.new('Pod/SubspecOSX', '1.0'),
          Dependency.new('Pod/SubspeciOS', '1.0')]
      end

      it 'returns all the dependencies for a given platform' do
        @spec.all_dependencies(:ios).sort.should == [
          Dependency.new('AFNetworking'),
          Dependency.new('Pod/Subspec', '1.0'),
          Dependency.new('Pod/SubspeciOS', '1.0')]
      end
    end

    #-------------------------------------------------------------------------#

    describe 'DSL Helpers' do
      before do
        @spec = Spec.new do |s|
          s.name = 'Pod'
          s.version = '1.0'
          s.subspec 'Subspec' do |_sp|
          end
        end
        @subspec = @spec.subspecs.first
      end

      it 'reports if it is locally sourced' do
        @spec.source = { 'path' => '/tmp/local/path' }
        @spec.local?.should.be.true
      end

      it 'returns whether it is supported on a given platform' do
        @spec.platform = :ios, '4.0'
        @spec.supported_on_platform?(:ios).should.be.true
        @spec.supported_on_platform?(:ios, '4.0').should.be.true
        @spec.supported_on_platform?(:ios, '3.0').should.be.false
        @spec.supported_on_platform?(:osx).should.be.false
        @spec.supported_on_platform?(:osx, '10.5').should.be.false
      end

      it 'returns the available platforms for which the pod is supported' do
        @spec.platform = :ios, '4.0'
        @spec.available_platforms.should == [Platform.new(:ios, '4.0')]
      end

      it 'inherits the name of the supported platforms from the parent' do
        @spec.platform = :ios, '4.0'
        @subspec.available_platforms.should == [Platform.new(:ios, '4.0')]
      end

      it 'returns the deployment target for the given platform' do
        @spec.platform = :ios, '4.0'
        @spec.deployment_target(:ios).should == '4.0'
      end

      it 'allows a subspec to override the deployment target of the parent' do
        @spec.platform = :ios, '4.0'
        @subspec.ios.deployment_target = '5.0'
        @subspec.deployment_target(:ios).should == '5.0'
      end

      it 'inherits the deployment target from the parent' do
        @spec.platform = :ios, '4.0'
        @subspec.deployment_target(:ios).should == '4.0'
      end

      it 'returns the names of the supported platforms as specified by the user' do
        @spec.platform = :ios, '4.0'
        @spec.send(:supported_platform_names).should == ['ios']
      end

      it 'inherits the supported platform from the parent' do
        @spec.platform = :ios
        @subspec.send(:supported_platform_names).should == ['ios']
      end

      it 'returns the consumer for the given symbolic name of a platform' do
        @spec.ios.source_files = 'ios-files'
        consumer = @spec.consumer(:ios)
        consumer.spec.should == @spec
        consumer.platform_name.should == :ios
        consumer.source_files.should == ['ios-files']
      end

      it 'returns the consumer of a given platform' do
        consumer = @spec.consumer(Platform.new :ios)
        consumer.spec.should == @spec
        consumer.platform_name.should == :ios
      end

      it 'caches the consumers per platform' do
        @spec.consumer(:ios).should.equal @spec.consumer(:ios)
        @spec.consumer(:ios).platform_name.should == :ios
        @spec.consumer(:osx).platform_name.should == :osx
      end
    end

    #-------------------------------------------------------------------------#

    describe 'DSL Attribute writers' do
      before do
        @spec = Spec.new
      end

      it 'stores the value of an attribute' do
        @spec.store_attribute(:attribute, 'value')
        @spec.attributes_hash.should == {
          'name' => nil,
          'attribute' => 'value',
        }
      end

      it 'stores the value of an attribute for a given platform' do
        @spec.store_attribute(:attribute, 'value', :ios)
        @spec.attributes_hash.should == {
          'name' => nil,
          'ios' => { 'attribute' => 'value' },
        }
      end

      it 'converts the keys of the hashes to a string' do
        @spec.store_attribute(:attribute, :key => 'value')
        @spec.attributes_hash.should == {
          'name' => nil,
          'attribute' => { 'key' => 'value' },
        }
      end

      it 'strips heredoc leading space from strings' do
        value = <<-EOS
          foo
            bar
        EOS
        @spec.store_attribute(:attribute, value)
        @spec.attributes_hash.should == {
          'name' => nil,
          'attribute' => "foo\n  bar",
        }
      end

      it 'strips trailing space from strings' do
        value = "foo\n"
        @spec.store_attribute(:attribute, value)
        @spec.attributes_hash.should == {
          'name' => nil,
          'attribute' => 'foo',
        }
      end

      it 'declares attribute writer methods' do
        Specification::DSL.attributes.values.each do |attr|
          value = case attr.supported_types.first
                  when Array then %w(a_value)
                  when FalseClass then false
                  when Hash then { :key => 'value' }
                  when String then 'a_value'
                  when TrueClass then true
                  end

          @spec.send(attr.writer_name, value)
          @spec.attributes_hash[attr.name.to_s].should == value
        end
      end

      it 'supports the singular form of attribute writer methods' do
        singular_attrs = Specification::DSL.attributes.values.select(&:writer_singular_form)
        singular_attrs.each do |attr|
          @spec.send(attr.writer_name, 'a_value')
          @spec.attributes_hash[attr.name.to_s].should == 'a_value'
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Initialization from a file' do
      it 'can be initialized from a file' do
        spec = Spec.from_file(fixture('BananaLib.podspec'))
        spec.class.should == Spec
        spec.name.should == 'BananaLib'
      end

      it 'can be initialized from a JSON file' do
        spec = Spec.from_file(fixture('BananaLib.podspec.json'))
        spec.class.should == Spec
        spec.name.should == 'BananaLib'
      end

      it "presents an informative if the given file file doesn't exits" do
        should.raise Informative do
          Spec.from_file('Missing.podspec')
        end.message.should.match /No podspec exists/
      end

      it "presents an informative if it can't handle the specification format" do
        Pathname.any_instance.stubs(:exist?).returns(true)
        File.stubs(:open).returns('')
        should.raise Informative do
          Spec.from_file('Missing.podspec.csv')
        end.message.should.match /Unsupported specification format/
      end

      it "is initialized in the context of the file's directory" do
        contents = File.read fixture('BananaLib.podspec')
        contents.sub!(/s\.name.*= '.+'/, 's.name = File.basename(Dir.pwd) + File.expand_path(__FILE__)')
        File.any_instance.stubs(:read).returns(contents)

        spec = Spec.from_file(fixture('BananaLib.podspec'))
        spec.class.should == Spec
        spec.name.should == 'fixtures' + fixture('BananaLib.podspec').to_s

        spec = Spec.from_file(fixture('BananaLib.podspec').relative_path_from(Pathname.pwd))
        spec.class.should == Spec
        spec.name.should == 'fixtures' + fixture('BananaLib.podspec').to_s
      end

      #--------------------------------------#

      before do
        @path = fixture('BananaLib.podspec')
        @spec = Spec.from_file(@path)
      end

      it 'returns the checksum of the file in which it is defined' do
        @spec.checksum.should == '4fb39cb6f34f694ab489d39df699c5b7c7f9ac79'
      end

      it 'returns a nil checksum if the specification is not defined in a file' do
        spec = Spec.new
        spec.checksum.should.be.nil
      end

      it 'reports the file from which it was initialized' do
        @spec.defined_in_file.should == @path
      end

      it 'raises if there is an attempt to set the file in which the spec is defined for a subspec' do
        spec = Spec.new do |s|
          s.name = 'Pod'
          s.version = '1.0'
          s.subspec 'Subspec' do |_sp|
          end
        end
        should.raise StandardError do
          spec.subspecs.first.defined_in_file = 'Some-file'
        end.message.should.match /can be set only for root specs/
      end
    end

    #-------------------------------------------------------------------------#

    describe 'module name' do
      it 'uses the specification name as module name by default' do
        spec = Specification.new(nil, 'Three20')
        spec.module_name.should == 'Three20'
      end

      it 'converts the name to a C99 identifier if required' do
        spec = Specification.new(nil, '500px')
        spec.module_name.should == '_500px'
      end

      it 'uses the header_dir as module name if specified' do
        spec = Specification.new(nil, 'Three20.swift')
        spec.header_dir = 'Three20'
        spec.module_name.should == 'Three20'
      end

      it 'converts the header_dir to a C99 identifier if required' do
        spec = Specification.new(nil, 'Three20.swift')
        spec.header_dir = 'Three-20'
        spec.module_name.should == 'Three_20'
      end

      it 'uses the defined module name if specified' do
        spec = Specification.new(nil, 'Three20.swift')
        spec.header_dir = 'Three20Core'
        spec.module_name = 'Three20'
        spec.module_name.should == 'Three20'
      end
    end

    #-------------------------------------------------------------------------#

    describe '#c99ext_identifier' do
      before do
        @spec = Specification.new
      end

      it 'should mask, but keep leading numbers' do
        @spec.send(:c99ext_identifier, '123BananaLib').should == '_123BananaLib'
      end

      it 'should mask invalid chars' do
        @spec.send(:c99ext_identifier, 'iOS-App BânánàLïb').should == 'iOS_App_BananaLib'
      end

      it 'should flatten multiple underscores to a single one' do
        @spec.send(:c99ext_identifier, '$.swift').should == '_swift'
      end
    end

    #-------------------------------------------------------------------------#
  end
end
