require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  class Installer
    describe SandboxHeaderLinker do
      describe 'in general' do
        before do
          @pod_target = fixture_pod_target('banana-lib/BananaLib.podspec')
          @file_accessor = @pod_target.file_accessors.first
          @linker = SandboxHeaderLinker.new(config.sandbox, [@pod_target])
        end
        it 'does not symlink headers that belong to test specs' do
          coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
          coconut_test_spec = coconut_spec.test_specs.first
          coconut_pod_target = fixture_pod_target_with_specs([coconut_spec, coconut_test_spec], false)
          public_headers_root = config.sandbox.public_headers.root
          private_headers_root = coconut_pod_target.build_headers.root
          header_linker = SandboxHeaderLinker.new(config.sandbox, [coconut_pod_target])
          header_linker.link!
          (public_headers_root + 'CoconutLib/Coconut.h').should.exist
          (public_headers_root + 'CoconutLib/CoconutTestHeader.h').should.not.exist
          (private_headers_root + 'CoconutLib/Coconut.h').should.exist
          (private_headers_root + 'CoconutLib/CoconutTestHeader.h').should.not.exist
        end

        it 'links the public headers meant for the user for a vendored framework' do
          pod_target_one = fixture_pod_target('banana-lib/BananaLib.podspec', true)
          pod_target_two = fixture_pod_target('monkey/monkey.podspec', true)
          header_linker = SandboxHeaderLinker.new(config.sandbox, [pod_target_one, pod_target_two])
          header_linker.link!
          headers_root = config.sandbox.public_headers.root
          banana_headers = [headers_root + 'BananaLib/Banana.h', headers_root + 'BananaLib/MoreBanana.h']
          banana_headers.each { |banana_header| banana_header.should.not.exist }
          monkey_header = headers_root + 'monkey/monkey.h'
          monkey_header.should.exist # since it lives outside of the vendored framework
          config.sandbox.public_headers.search_paths(pod_target_one.platform).should == %w(
            ${PODS_ROOT}/Headers/Public
            ${PODS_ROOT}/Headers/Public/monkey
          )
        end

        it 'links the headers required for building the pod target' do
          @linker.link!
          headers_root = @pod_target.build_headers.root
          public_headers = [headers_root + 'BananaLib/Banana.h', headers_root + 'BananaLib/MoreBanana.h']
          private_header = headers_root + 'BananaLib/BananaPrivate.h'
          framework_header = headers_root + 'BananaLib/Bananalib/Bananalib.h'
          public_headers.each { |public_header| public_header.should.exist }
          private_header.should.exist
          framework_header.should.not.exist
        end

        it 'links the public headers meant for the user' do
          @linker.link!
          headers_root = config.sandbox.public_headers.root
          public_headers = [headers_root + 'BananaLib/Banana.h', headers_root + 'BananaLib/MoreBanana.h']
          private_header = headers_root + 'BananaLib/BananaPrivate.h'
          framework_header = headers_root + 'BananaLib/Bananalib/Bananalib.h'
          framework_subdir_header = headers_root + 'BananaLib/Bananalib/SubDir/SubBananalib.h'
          public_headers.each { |public_header| public_header.should.exist }
          private_header.should.not.exist
          framework_header.should.not.exist
          framework_subdir_header.should.not.exist
        end

        it 'does not link public headers from vendored framework, when frameworks required' do
          @pod_target.stubs(:build_type).returns(Target::BuildType.dynamic_framework)
          @linker.link!
          headers_root = config.sandbox.public_headers.root
          framework_header = headers_root + 'BananaLib/Bananalib/Bananalib.h'
          framework_header.should.not.exist
        end
      end
      describe '#header_mappings' do
        before do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          @pod_target = fixture_pod_target(spec)
          @file_accessor = @pod_target.file_accessors.first
          @sandbox_header_linker = SandboxHeaderLinker.new(config.sandbox, [@pod_target])
        end

        it 'returns the correct public header mappings' do
          headers_sandbox = Pathname.new('BananaLib')
          headers = [Pathname.new('Banana.h')]
          mappings = @sandbox_header_linker.send(:header_mappings, headers_sandbox, @file_accessor, headers)
          mappings.should == {
            Pathname.new('BananaLib') => [Pathname.new('Banana.h')],
          }
        end

        it 'takes into account the header dir specified in the spec for public headers' do
          headers_sandbox = Pathname.new('BananaLib')
          headers = [Pathname.new('Banana.h')]
          @file_accessor.spec_consumer.stubs(:header_dir).returns('Sub_dir')
          mappings = @sandbox_header_linker.send(:header_mappings, headers_sandbox, @file_accessor, headers)
          mappings.should == {
            Pathname.new('BananaLib/Sub_dir') => [Pathname.new('Banana.h')],
          }
        end

        it 'takes into account the header dir specified in the spec for private headers' do
          headers_sandbox = Pathname.new('BananaLib')
          headers = [Pathname.new('Banana.h')]
          @file_accessor.spec_consumer.stubs(:header_dir).returns('Sub_dir')
          mappings = @sandbox_header_linker.send(:header_mappings, headers_sandbox, @file_accessor, headers)
          mappings.should == {
            Pathname.new('BananaLib/Sub_dir') => [Pathname.new('Banana.h')],
          }
        end

        it 'takes into account the header mappings dir specified in the spec' do
          headers_sandbox = Pathname.new('BananaLib')
          header_1 = @file_accessor.root + 'BananaLib/sub_dir/dir_1/banana_1.h'
          header_2 = @file_accessor.root + 'BananaLib/sub_dir/dir_2/banana_2.h'
          headers = [header_1, header_2]
          @file_accessor.spec_consumer.stubs(:header_mappings_dir).returns('BananaLib/sub_dir')
          mappings = @sandbox_header_linker.send(:header_mappings, headers_sandbox, @file_accessor, headers)
          mappings.should == {
            (headers_sandbox + 'dir_1') => [header_1],
            (headers_sandbox + 'dir_2') => [header_2],
          }
        end
      end
    end
  end
end
