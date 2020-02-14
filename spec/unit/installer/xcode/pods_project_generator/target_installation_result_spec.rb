require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        describe TargetInstallationResult do
          describe 'In General' do
            before do
              @coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
              @coconut_test_spec = @coconut_spec.test_specs.first
              @pod_target = fixture_pod_target_with_specs([@coconut_spec, @coconut_test_spec])
            end

            it 'sets correct defaults' do
              native_target = stub('native_target')
              result = TargetInstallationResult.new(@pod_target, native_target)
              result.resource_bundle_targets.should == []
              result.test_native_targets.should == []
              result.test_resource_bundle_targets.should == {}
              result.test_app_host_targets.should == []
              result.app_native_targets.should == {}
              result.app_resource_bundle_targets.should == {}
            end

            it 'groups test specs by the native target they are part of' do
              native_target = stub('native_target')
              test_native_target = stub('test_native_target', :symbol_type => :unit_test_bundle, :name => 'CoconutLib-Unit-Tests')
              result = TargetInstallationResult.new(@pod_target, native_target, [], [test_native_target])
              result.test_specs_by_native_target.should == { test_native_target => @coconut_test_spec }
            end

            it 'does not return test specs by native target which they were not integrated' do
              native_target = stub('native_target')
              result = TargetInstallationResult.new(@pod_target, native_target, [], [])
              result.test_specs_by_native_target.should.be.empty
            end
          end
        end
      end
    end
  end
end
