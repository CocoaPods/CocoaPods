require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::SandboxDirCleaner do
    before do
      @sandbox = config.sandbox
      @user_project_path = @sandbox.root + 'UserProject.xcodeproj'
      @user_project = Xcodeproj::Project.new(@user_project_path)
      @user_project.save
      @banana_pod_target = fixture_pod_target('banana-lib/BananaLib.podspec')
      coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
      coconut_spec.module_name = 'CoconutLibModule'
      @coconut_pod_target = fixture_pod_target(coconut_spec)
      @aggregate_target = AggregateTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios,
                                              fixture_target_definition('MyApp'), config.sandbox.root.dirname,
                                              @user_project, ['A346496C14F9BE9A0080D870'],
                                              'Release' => [@coconut_pod_target], 'Debug' => [@coconut_pod_target])
      @cleaner = Installer::SandboxDirCleaner.new(config.sandbox, [@banana_pod_target, @coconut_pod_target],
                                                  [@aggregate_target])
      FileUtils.mkdir_p(@sandbox.target_support_files_dir(@banana_pod_target.name))
      FileUtils.mkdir_p(@sandbox.target_support_files_dir(@coconut_pod_target.name))
      FileUtils.mkdir_p(@sandbox.target_support_files_dir(@aggregate_target.name))
    end

    it 'cleans up stale target support directories' do
      unknown_target_path = @sandbox.target_support_files_dir('Pods-Unknown')
      FileUtils.mkdir_p(unknown_target_path)

      @cleaner.expects(:remove_dir).with(unknown_target_path)
      @cleaner.clean!
    end

    it 'does not remove pod or aggregate support files and directories' do
      @cleaner.expects(:remove_dir).never
      @cleaner.clean!
    end

    it 'cleans up stale headers and keeps pod target headers' do
      random_pod_private_headers = @banana_pod_target.build_headers.root.join('RandomPod')
      random_pod_public_headers = @sandbox.public_headers.root.join('PublicPod')
      banana_lib_public_headers = @sandbox.public_headers.root.join('BananaLib')
      banana_lib_private_headers = @banana_pod_target.build_headers.root.join('BananaLib')
      coconut_lib_public_headers = @sandbox.public_headers.root.join('CoconutLibModule')
      coconut_lib_private_headers = @coconut_pod_target.build_headers.root.join('CoconutLibModule')
      FileUtils.mkdir_p(random_pod_private_headers)
      FileUtils.mkdir_p(random_pod_public_headers)
      FileUtils.mkdir_p(banana_lib_public_headers)
      FileUtils.mkdir_p(banana_lib_private_headers)
      FileUtils.mkdir_p(coconut_lib_public_headers)
      FileUtils.mkdir_p(coconut_lib_private_headers)
      @cleaner.expects(:remove_dir).with(random_pod_private_headers)
      @cleaner.expects(:remove_dir).with(random_pod_public_headers)
      @cleaner.expects(:remove_dir).with(coconut_lib_public_headers).never
      @cleaner.expects(:remove_dir).with(coconut_lib_private_headers)
      @cleaner.clean!
      FileUtils.rm_rf(random_pod_private_headers)
      FileUtils.rm_rf(random_pod_public_headers)
      FileUtils.rm_rf(banana_lib_public_headers)
      FileUtils.rm_rf(banana_lib_private_headers)
      FileUtils.rm_rf(coconut_lib_public_headers)
      FileUtils.rm_rf(coconut_lib_private_headers)
    end

    it 'cleans up stale projects and keeps pod target projects and user projects' do
      @banana_pod_target.stubs(:project_name).returns('CustomProject')
      coconut_lib_project_path = @sandbox.root + 'CoconutLib.xcodeproj'
      banana_lib_default_project_path = @sandbox.root + 'BananaLib.xcodeproj'
      banana_lib_custom_project_path = @sandbox.root + 'CustomProject.xcodeproj'
      unknown_project_path = @sandbox.root + 'Unknown.xcodeproj'
      FileUtils.mkdir_p(coconut_lib_project_path)
      FileUtils.mkdir_p(banana_lib_default_project_path)
      FileUtils.mkdir_p(banana_lib_custom_project_path)
      FileUtils.mkdir_p(unknown_project_path)
      @cleaner.expects(:remove_dir).with(@user_project_path).never
      @cleaner.expects(:remove_dir).with(coconut_lib_project_path).never
      @cleaner.expects(:remove_dir).with(banana_lib_custom_project_path).never
      @cleaner.expects(:remove_dir).with(banana_lib_default_project_path)
      @cleaner.expects(:remove_dir).with(unknown_project_path)
      @cleaner.clean!
      FileUtils.rm_rf(@user_project_path)
      FileUtils.rm_rf(coconut_lib_project_path)
      FileUtils.rm_rf(banana_lib_custom_project_path)
      FileUtils.rm_rf(banana_lib_default_project_path)
      FileUtils.rm_rf(unknown_project_path)
    end
  end
end
