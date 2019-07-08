require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  describe Specification::Linter::Analyzer do
    describe 'File patterns & Build settings' do
      before do
        fixture_path = 'spec-repos/test_repo/Specs/BananaLib/1.0/BananaLib.podspec'
        podspec_path = fixture(fixture_path)
        linter = Specification::Linter.new(podspec_path)
        @spec = linter.spec
        results = Specification::Linter::Results.new
        @analyzer = Specification::Linter::Analyzer.new(@spec.consumer(:ios), results)
      end

      #----------------------------------------#

      describe 'Bad types' do
        it 'fails a spec with an attribute of the wrong type' do
          @spec.summary = ['Summary in an array']
          results = @analyzer.analyze
          results.count.should.be.equal(2)
          expected = 'Unacceptable type `Array`'
          results.first.message.should.include?(expected)
          results.first.attribute_name.should.include?('attribute')
        end
      end

      #----------------------------------------#

      describe 'Root attributes' do
        it 'fails a subspec with a root attribute' do
          subspec = @spec.subspec 'subspec' do |sp|
            sp.homepage = 'http://example.org'
          end
          results = Specification::Linter::Results.new
          @analyzer = Specification::Linter::Analyzer.new(subspec.consumer(:ios), results)
          results = @analyzer.analyze
          results.count.should.be.equal(1)
          expected = 'Can\'t set `homepage` attribute for subspecs (in `BananaLib/subspec`).'
          results.first.message.should.include?(expected)
          results.first.attribute_name.should.include?('attribute')
        end
      end

      #----------------------------------------#

      describe 'Attribute Occurrence' do
        it 'disallows root only attributes into subspecs' do
          subspec = @spec.subspec 'subspec' do |sp|
            sp.version = '1.0.0'
          end
          results = Specification::Linter::Results.new
          @analyzer = Specification::Linter::Analyzer.new(subspec.consumer(:ios), results)
          results = @analyzer.analyze
          results.count.should.be.equal(1)
          expected = "Can't set `version` attribute for subspecs (in `BananaLib/subspec`)."
          results.first.message.should.include?(expected)
          results.first.attribute_name.should.include?('attribute')
        end

        it 'disallows test only attributes into non test specs' do
          @spec.test_spec {}
          @spec.requires_app_host = true
          results = @analyzer.analyze
          results.count.should.be.equal(1)
          expected = 'Attribute `requires_app_host` can only be set within test specs (in `BananaLib`).'
          results.first.message.should.include?(expected)
          results.first.attribute_name.should.include?('attribute')
        end

        it 'allows test only attributes into test specs' do
          @spec.test_spec {}
          test_spec = @spec.test_specs.first
          test_spec.requires_app_host = true
          results = Specification::Linter::Results.new
          @analyzer = Specification::Linter::Analyzer.new(test_spec.consumer(:ios), results)
          results = @analyzer.analyze
          results.should.be.empty?
        end
      end

      #----------------------------------------#

      describe 'Unknown keys check' do
        it 'validates a spec with valid keys' do
          results = @analyzer.analyze
          results.should.be.empty?
        end

        it 'validates a spec with multi-platform attributes' do
          @spec.ios.requires_arc = true
          results = @analyzer.analyze
          results.should.be.empty?
        end

        it 'fails a spec with unknown keys' do
          @spec.attributes_hash['unknown_key'] = true
          results = @analyzer.analyze
          results.count.should.be.equal(1)
          expected = 'Unrecognized `unknown_key` key'
          results.first.message.should.include?(expected)
          results.first.attribute_name.should.include?('attributes')
        end

        it 'fails a spec with unknown multi-platform key' do
          @spec.attributes_hash['ios'] = { 'unknown_key' => true }
          results = @analyzer.analyze
          results.count.should.be.equal(1)
          expected = 'Unrecognized `unknown_key` key'
          results.first.message.should.include?(expected)
          results.first.attribute_name.should.include?('attributes')
        end

        it 'validates a spec with valid sub-keys' do
          @spec.license = { :type => 'MIT' }
          results = @analyzer.analyze
          results.should.be.empty?
        end

        it 'fails a spec with unknown sub-keys' do
          @spec.license = { :is_safe_for_work => true }
          results = @analyzer.analyze
          results.count.should.be.equal(1)
          expected = 'Unrecognized `is_safe_for_work` key'
          results.first.message.should.include?(expected)
          results.first.attribute_name.should.include?('keys')
        end

        it 'validates a spec with valid minor sub-keys' do
          @spec.source = { :git => 'example.com', :branch => 'master' }
          results = @analyzer.analyze
          results.should.be.empty?
        end

        it 'fails a spec with a missing primary sub-keys' do
          @spec.source = { :branch => 'example.com', :commit => 'MyLib' }
          results = @analyzer.analyze
          results.count.should.be.equal(1)
          expected = 'Missing primary key for `source` attribute.'
          results.first.message.should.include?(expected)
          results.first.attribute_name.should.include?('keys')
        end

        it 'fails a spec with invalid secondary sub-keys' do
          @spec.source = { :git => 'example.com', :folder => 'MyLib' }
          results = @analyzer.analyze
          results.count.should.be.equal(1)
          expected = 'Incompatible `folder` key(s) with `git`'
          results.first.message.should.include?(expected)
          results.first.attribute_name.should.include?('keys')
        end

        it 'fails a spec with multiple primary keys' do
          @spec.source = { :git => 'example.com', :http => 'example.com' }
          results = @analyzer.analyze
          results.count.should.be.equal(1)
          expected = 'Incompatible `git, http` keys'
          results.first.message.should.include?(expected)
          results.first.attribute_name.should.include?('keys')
        end

        it 'fails a spec invalid secondary sub-keys when no sub-keys are supported' do
          @spec.source = { :http => 'example.com', :unsupported => true }
          results = @analyzer.analyze
          results.count.should.be.equal(1)
          expected = 'Incompatible `unsupported` key(s) with `http`'
          results.first.message.should.include?(expected)
          results.first.attribute_name.should.include?('keys')
        end
      end

      #----------------------------------------#

      describe 'File Patterns' do
        it 'checks if any file patterns is absolute' do
          @spec.source_files = '/Classes'
          results = @analyzer.analyze
          results.count.should.be.equal(1)
          expected = 'patterns must be relative'
          results.first.message.should.include?(expected)
          results.first.attribute_name.should.include?('File Patterns')
        end

        it 'checks if a specification is empty' do
          consumer = Specification::Consumer
          consumer.any_instance.stubs(:source_files).returns([])
          consumer.any_instance.stubs(:resources).returns({})
          consumer.any_instance.stubs(:resource_bundles).returns([])
          consumer.any_instance.stubs(:preserve_paths).returns([])
          consumer.any_instance.stubs(:dependencies).returns([])
          consumer.any_instance.stubs(:vendored_libraries).returns([])
          consumer.any_instance.stubs(:vendored_frameworks).returns([])

          results = @analyzer.analyze
          results.count.should.be.equal(1)
          results.first.message.should.include?('spec is empty')
          results.first.attribute_name.should.include?('File Patterns')
        end
      end

      #----------------------------------------#

      describe 'Requires ARC' do
        it 'supports the declaration of the attribute per platform' do
          results = @analyzer.analyze
          results.should.be.empty?
        end

        it 'supports the declaration of the attribute in the parent' do
          @spec = Spec.new do |s|
            s.subspec 'SubSpec' do |_sp|
            end
          end
          consumer = @spec.consumer(:ios)
          results = Specification::Linter::Results.new
          @analyzer = Specification::Linter::Analyzer.new(consumer, results)
          results = @analyzer.analyze
          results.should.be.empty?
        end
      end
    end
  end
end
