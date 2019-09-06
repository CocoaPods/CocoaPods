require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  class Installer
    describe SandboxHeaderPathsInstaller do
      describe 'In general' do
        it 'add the public headers meant for the user to the header search paths' do
          pod_target_one = fixture_pod_target('banana-lib/BananaLib.podspec', BuildType.dynamic_framework)
          pod_target_two = fixture_pod_target('monkey/monkey.podspec', BuildType.dynamic_framework)
          installer = SandboxHeaderPathsInstaller.new(config.sandbox, [pod_target_one, pod_target_two])
          installer.install!
          config.sandbox.public_headers.search_paths(pod_target_one.platform).should == %w(
            ${PODS_ROOT}/Headers/Public
            ${PODS_ROOT}/Headers/Public/monkey
          )
        end

        it 'includes headers in the search paths for libraries' do
          pod_target_one = fixture_pod_target('banana-lib/BananaLib.podspec', BuildType.static_library)
          pod_target_two = fixture_pod_target('monkey/monkey.podspec', BuildType.static_library)
          installer = SandboxHeaderPathsInstaller.new(config.sandbox, [pod_target_one, pod_target_two])
          installer.install!
          config.sandbox.public_headers.search_paths(pod_target_one.platform).should == %w(
            ${PODS_ROOT}/Headers/Public
            ${PODS_ROOT}/Headers/Public/BananaLib
            ${PODS_ROOT}/Headers/Public/monkey
          )
        end
      end
    end
  end
end
