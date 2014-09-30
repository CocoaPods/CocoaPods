require File.expand_path('../../../spec_helper', __FILE__)

# @return [Analyzer] the sample analyzer.
#
def create_analyzer
  @podfile = Pod::Podfile.new do
    platform :ios, '6.0'
    xcodeproj 'SampleProject/SampleProject'
    pod 'JSONKit',                     '1.5pre'
    pod 'AFNetworking',                '1.0.1'
    pod 'SVPullToRefresh',             '0.4'
    pod 'libextobjc/EXTKeyPathCoding', '0.2.3'
  end

  hash = {}
  hash['PODS'] = ['JSONKit (1.4)', 'NUI (0.2.0)', 'SVPullToRefresh (0.4)']
  hash['DEPENDENCIES'] = %w(JSONKit NUI SVPullToRefresh)
  hash['SPEC CHECKSUMS'] = {}
  hash['COCOAPODS'] = Pod::VERSION
  lockfile = Pod::Lockfile.new(hash)

  SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
  analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, lockfile)
end

#-----------------------------------------------------------------------------#

module Pod
  describe Installer::Analyzer do

    before do
      @analyzer = create_analyzer
    end

    describe 'Analysis' do

      it 'returns whether an installation should be performed' do
        @analyzer.needs_install?.should.be.true
      end

      it 'returns whether the Podfile has changes' do
        analysis_result = @analyzer.analyze(false)
        @analyzer.podfile_needs_install?(analysis_result).should.be.true
      end

      it 'returns whether the sandbox is not in sync with the lockfile' do
        analysis_result = @analyzer.analyze(false)
        @analyzer.sandbox_needs_install?(analysis_result).should.be.true
      end

      #--------------------------------------#

      it 'computes the state of the Podfile respect to the Lockfile' do
        state = @analyzer.analyze.podfile_state
        state.added.should     == %w(AFNetworking libextobjc)
        state.changed.should   == ['JSONKit']
        state.unchanged.should == ['SVPullToRefresh']
        state.deleted.should   == ['NUI']
      end

      #--------------------------------------#

      it 'updates the repositories by default' do
        config.skip_repo_update = false
        SourcesManager.expects(:update).twice
        @analyzer.analyze
      end

      it 'does not update unused sources' do
        config.skip_repo_update = false
        @analyzer.stubs(:sources).returns(SourcesManager.master)
        SourcesManager.expects(:update).once.with('master')
        @analyzer.analyze
      end

      it 'does not updates the repositories if config indicates to skip them' do
        config.skip_repo_update = true
        SourcesManager.expects(:update).never
        @analyzer.analyze
      end

      #--------------------------------------#

      it 'generates the libraries which represent the target definitions' do
        target = @analyzer.analyze.targets.first
        target.pod_targets.map(&:name).sort.should == [
          'Pods-JSONKit',
          'Pods-AFNetworking',
          'Pods-SVPullToRefresh',
          'Pods-libextobjc',
        ].sort
        target.support_files_dir.should == config.sandbox.target_support_files_dir('Pods')

        target.user_project_path.to_s.should.include 'SampleProject/SampleProject'
        target.client_root.to_s.should.include 'SampleProject'
        target.user_target_uuids.should == ['A346496C14F9BE9A0080D870']
        user_proj = Xcodeproj::Project.open(target.user_project_path)
        user_proj.objects_by_uuid[target.user_target_uuids.first].name.should == 'SampleProject'
        target.user_build_configurations.should == {
          'Debug'     => :debug,
          'Release'   => :release,
          'Test'      => :release,
          'App Store' => :release,
        }
        target.platform.to_s.should == 'iOS 6.0'
      end

      it 'generates the integration library appropriately if the installation will not integrate' do
        config.integrate_targets = false
        target = @analyzer.analyze.targets.first

        target.client_root.should == config.installation_root
        target.user_target_uuids.should == []
        target.user_build_configurations.should == {}
        target.platform.to_s.should == 'iOS 6.0'
      end

      it 'returns all the configurations the user has in any of its projects and/or targets' do
        target_definition = @analyzer.podfile.target_definition_list.first
        target_definition.stubs(:build_configurations).returns('AdHoc' => :test)
        @analyzer.analyze.all_user_build_configurations.should == {
          'Debug'     => :debug,
          'Release'   => :release,
          'AdHoc'     => :test,
          'Test'      => :release,
          'App Store' => :release,
        }
      end

      #--------------------------------------#

      it 'locks the version of the dependencies which did not change in the Podfile' do
        @analyzer.analyze
        @analyzer.send(:locked_dependencies).map(&:to_s).should == ['SVPullToRefresh (= 0.4)']
      end

      it 'does not lock the dependencies in update mode' do
        @analyzer.update = true
        @analyzer.analyze
        @analyzer.send(:locked_dependencies).map(&:to_s).should == []
      end

      #--------------------------------------#

      it 'fetches the dependencies with external sources' do
        podfile_state = Installer::Analyzer::SpecsState.new
        podfile_state.added << 'BananaLib'
        @analyzer.stubs(:result).returns(stub(:podfile_state => podfile_state))
        @podfile.stubs(:dependencies).returns([Dependency.new('BananaLib', :git => 'example.com')])
        ExternalSources::DownloaderSource.any_instance.expects(:fetch)
        @analyzer.send(:fetch_external_sources)
      end

      xit 'it fetches the specification from either the sandbox or from the remote be default' do
        dependency = Dependency.new('Name', :git => 'www.example.com')
        ExternalSources::DownloaderSource.any_instance.expects(:specification_from_external).returns(Specification.new).once
        @resolver.send(:set_from_external_source, dependency)
      end

      xit 'it fetches the specification from the remote if in update mode' do
        dependency = Dependency.new('Name', :git => 'www.example.com')
        ExternalSources::DownloaderSource.any_instance.expects(:specification).returns(Specification.new).once
        @resolver.update_external_specs = false
        @resolver.send(:set_from_external_source, dependency)
      end

      xit 'it fetches the specification only from the sandbox if pre-downloads are disabled' do
        dependency = Dependency.new('Name', :git => 'www.example.com')
        Sandbox.any_instance.expects(:specification).returns(Specification.new).once
        @resolver.allow_pre_downloads = true
        @resolver.send(:set_from_external_source, dependency)
      end

      #--------------------------------------#

      it 'resolves the dependencies' do
        @analyzer.analyze.specifications.map(&:to_s).should == [
          'AFNetworking (1.0.1)',
          'JSONKit (1.5pre)',
          'SVPullToRefresh (0.4)',
          'libextobjc/EXTKeyPathCoding (0.2.3)',
        ]
      end

      xit 'removes the specifications of the changed pods to prevent confusion in the resolution process' do
        @analyzer.allow_pre_downloads = true
        podspec = @analyzer.sandbox.root + 'Local Podspecs/JSONKit.podspec'
        podspec.dirname.mkpath
        File.open(podspec, 'w') { |f| f.puts('test') }
        @analyzer.analyze
        podspec.should.not.exist?
      end

      it 'adds the specifications to the correspondent libraries' do
        @analyzer.analyze.targets.first.pod_targets.map(&:specs).flatten.map(&:to_s).should == [
          'AFNetworking (1.0.1)',
          'JSONKit (1.5pre)',
          'SVPullToRefresh (0.4)',
          'libextobjc/EXTKeyPathCoding (0.2.3)',
        ]
      end

      #--------------------------------------#

      it 'computes the state of the Sandbox respect to the resolved dependencies' do
        @analyzer.stubs(:lockfile).returns(nil)
        state = @analyzer.analyze.sandbox_state
        state.added.sort.should == %w(AFNetworking JSONKit SVPullToRefresh libextobjc)
      end

    end

    #-------------------------------------------------------------------------#

    describe 'Private helpers' do

      describe '#compute_user_project_targets' do
        it 'uses the path specified in the target definition while computing the path of the user project' do
          target_definition = Podfile::TargetDefinition.new(:default, nil)
          target_definition.user_project_path = 'SampleProject/SampleProject'

          path = @analyzer.send(:compute_user_project_path, target_definition)
          path.to_s.should.include 'SampleProject/SampleProject.xcodeproj'
        end

        it 'raises if the user project of the target definition does not exists while computing the path of the user project' do
          target_definition = Podfile::TargetDefinition.new(:default, nil)
          target_definition.user_project_path = 'Test'

          e = lambda { @analyzer.send(:compute_user_project_path, target_definition) }.should.raise Informative
          e.message.should.match /Unable to find/
        end

        it 'if not specified in the target definition if looks if there is only one project' do
          target_definition = Podfile::TargetDefinition.new(:default, nil)
          config.installation_root = config.installation_root + 'SampleProject'

          path = @analyzer.send(:compute_user_project_path, target_definition)
          path.to_s.should.include 'SampleProject/SampleProject.xcodeproj'
        end

        it 'if not specified in the target definition if looks if there is only one project' do
          target_definition = Podfile::TargetDefinition.new(:default, nil)

          e = lambda { @analyzer.send(:compute_user_project_path, target_definition) }.should.raise Informative
          e.message.should.match /Could not.*select.*project/
        end

        it 'does not take aggregate targets into consideration' do
          aggregate_class = Xcodeproj::Project::Object::PBXAggregateTarget
          sample_project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
          sample_project = Xcodeproj::Project.open(sample_project_path)
          sample_project.targets.map(&:class).should.include(aggregate_class)

          native_targets = @analyzer.send(:native_targets, sample_project).map(&:class)
          native_targets.should.not.include(aggregate_class)
        end
      end

      #--------------------------------------#

      describe '#compute_user_project_targets' do

        it 'returns the targets specified in the target definition' do
          target_definition = Podfile::TargetDefinition.new(:default, nil)
          target_definition.link_with = ['UserTarget']
          user_project = Xcodeproj::Project.new('path')
          user_project.new_target(:application, 'FirstTarget', :ios)
          user_project.new_target(:application, 'UserTarget', :ios)

          targets = @analyzer.send(:compute_user_project_targets, target_definition, user_project)
          targets.map(&:name).should == ['UserTarget']
        end

        it 'raises if it is unable to find the targets specified by the target definition' do
          target_definition = Podfile::TargetDefinition.new(:default, nil)
          target_definition.link_with = ['UserTarget']
          user_project = Xcodeproj::Project.new('path')

          e = lambda { @analyzer.send(:compute_user_project_targets, target_definition, user_project) }.should.raise Informative
          e.message.should.match /Unable to find the targets/
        end

        it 'returns the target with the same name of the target definition' do
          target_definition = Podfile::TargetDefinition.new('UserTarget', nil)
          user_project = Xcodeproj::Project.new('path')
          user_project.new_target(:application, 'FirstTarget', :ios)
          user_project.new_target(:application, 'UserTarget', :ios)

          targets = @analyzer.send(:compute_user_project_targets, target_definition, user_project)
          targets.map(&:name).should == ['UserTarget']
        end

        it 'raises if the name of the target definition does not match any file' do
          target_definition = Podfile::TargetDefinition.new('UserTarget', nil)
          user_project = Xcodeproj::Project.new('path')
          e = lambda { @analyzer.send(:compute_user_project_targets, target_definition, user_project) }.should.raise Informative
          e.message.should.match /Unable to find a target named/
        end

        it 'returns the first target of the project if the target definition is named default' do
          target_definition = Podfile::TargetDefinition.new('Pods', nil)
          target_definition.link_with_first_target = true
          user_project = Xcodeproj::Project.new('path')
          user_project.new_target(:application, 'FirstTarget', :ios)
          user_project.new_target(:application, 'UserTarget', :ios)

          targets = @analyzer.send(:compute_user_project_targets, target_definition, user_project)
          targets.map(&:name).should == ['FirstTarget']
        end

        it 'raises if the default target definition cannot be linked because there are no user targets' do
          target_definition = Podfile::TargetDefinition.new(:default, nil)
          user_project = Xcodeproj::Project.new('path')
          e = lambda { @analyzer.send(:compute_user_project_targets, target_definition, user_project) }.should.raise Informative
          e.message.should.match /Unable to find a target/
        end

      end

      #--------------------------------------#

      describe '#compute_user_build_configurations' do

        it 'returns the user build configurations of the user targets' do
          user_project = Xcodeproj::Project.new('path')
          target = user_project.new_target(:application, 'Target', :ios)
          configuration = user_project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
          configuration.name = 'AppStore'
          target.build_configuration_list.build_configurations << configuration

          target_definition = Podfile::TargetDefinition.new(:default, nil)
          user_targets = [target]

          configurations = @analyzer.send(:compute_user_build_configurations, target_definition, user_targets)
          configurations.should == {
            'Debug'    => :debug,
            'Release'  => :release,
            'AppStore' => :release,
          }
        end

        it 'returns the user build configurations specified in the target definition' do
          target_definition = Podfile::TargetDefinition.new(:default, nil)
          target_definition.build_configurations = { 'AppStore' => :release }
          user_targets = []

          configurations = @analyzer.send(:compute_user_build_configurations, target_definition, user_targets)
          configurations.should == { 'AppStore' => :release }
        end

      end

      #--------------------------------------#

      describe '#compute_archs_for_target_definition' do

        it 'handles a single ARCH defined in a single user target' do
          user_project = Xcodeproj::Project.new('path')
          target = user_project.new_target(:application, 'Target', :ios)
          target.build_configuration_list.set_setting('ARCHS', 'armv7')

          target_definition = Podfile::TargetDefinition.new(:default, nil)
          target_definition.set_platform(:ios, '4.0')
          user_targets = [target]

          archs = @analyzer.send(:compute_archs_for_target_definition, target_definition, user_targets)
          archs.should == 'armv7'
        end

        it 'handles a single ARCH defined in multiple user targets' do
          user_project = Xcodeproj::Project.new('path')
          targeta = user_project.new_target(:application, 'Target', :ios)
          targeta.build_configuration_list.set_setting('ARCHS', 'armv7')
          targetb = user_project.new_target(:application, 'Target', :ios)
          targetb.build_configuration_list.set_setting('ARCHS', 'armv7')

          target_definition = Podfile::TargetDefinition.new(:default, nil)
          target_definition.set_platform(:ios, '4.0')
          user_targets = [targeta, targetb]

          archs = @analyzer.send(:compute_archs_for_target_definition, target_definition, user_targets)
          archs.should == 'armv7'
        end

        it 'handles an Array of ARCHs defined in a single user target' do
          user_project = Xcodeproj::Project.new('path')
          target = user_project.new_target(:application, 'Target', :ios)
          target.build_configuration_list.set_setting('ARCHS', %w(armv7 i386))

          target_definition = Podfile::TargetDefinition.new(:default, nil)
          target_definition.set_platform(:ios, '4.0')
          user_targets = [target]

          archs = @analyzer.send(:compute_archs_for_target_definition, target_definition, user_targets)
          %w(armv7 i386).each { |a| archs.should.include a }
        end

        it 'handles an Array of ARCHs defined multiple user targets' do
          user_project = Xcodeproj::Project.new('path')
          targeta = user_project.new_target(:application, 'Target', :ios)
          targeta.build_configuration_list.set_setting('ARCHS', %w(armv7 armv7s))
          targetb = user_project.new_target(:application, 'Target', :ios)
          targetb.build_configuration_list.set_setting('ARCHS', %w(armv7 i386))

          target_definition = Podfile::TargetDefinition.new(:default, nil)
          target_definition.set_platform(:ios, '4.0')
          user_targets = [targeta, targetb]

          archs = @analyzer.send(:compute_archs_for_target_definition, target_definition, user_targets)
          %w(armv7 armv7s i386).each { |a| archs.should.include a }
        end
      end

      #--------------------------------------#

      describe '#compute_platform_for_target_definition' do

        it 'returns the platform specified in the target definition' do
          target_definition = Podfile::TargetDefinition.new(:default, nil)
          target_definition.set_platform(:ios, '4.0')
          user_targets = []

          configurations = @analyzer.send(:compute_platform_for_target_definition, target_definition, user_targets)
          configurations.should == Platform.new(:ios, '4.0')
        end

        it 'infers the platform from the user targets' do
          user_project = Xcodeproj::Project.new('path')
          target = user_project.new_target(:application, 'Target', :ios)
          target.build_configuration_list.set_setting('SDKROOT', 'iphoneos')
          target.build_configuration_list.set_setting('IPHONEOS_DEPLOYMENT_TARGET', '4.0')

          target_definition = Podfile::TargetDefinition.new(:default, nil)
          user_targets = [target]

          configurations = @analyzer.send(:compute_platform_for_target_definition, target_definition, user_targets)
          configurations.should == Platform.new(:ios, '4.0')
        end

        it 'uses the lowest deployment target of the user targets if inferring the platform' do
          user_project = Xcodeproj::Project.new('path')
          target1 = user_project.new_target(:application, 'Target', :ios)
          configuration1 = target1.build_configuration_list.build_configurations.first
          target1.build_configuration_list.set_setting('SDKROOT', 'iphoneos')
          target1.build_configuration_list.set_setting('IPHONEOS_DEPLOYMENT_TARGET', '4.0')

          target2 = user_project.new_target(:application, 'Target', :ios)
          target2.build_configuration_list.set_setting('SDKROOT', 'iphoneos')
          target2.build_configuration_list.set_setting('IPHONEOS_DEPLOYMENT_TARGET', '6.0')

          target_definition = Podfile::TargetDefinition.new(:default, nil)
          user_targets = [target1, target2]

          configurations = @analyzer.send(:compute_platform_for_target_definition, target_definition, user_targets)
          configurations.should == Platform.new(:ios, '4.0')
        end

        it 'raises if the user targets have a different platform' do
          user_project = Xcodeproj::Project.new('path')
          target1 = user_project.new_target(:application, 'Target', :ios)
          target1.build_configuration_list.set_setting('SDKROOT', 'iphoneos')
          target1.build_configuration_list.set_setting('IPHONEOS_DEPLOYMENT_TARGET', '4.0')

          target2 = user_project.new_target(:application, 'Target', :ios)
          target2.build_configuration_list.set_setting('SDKROOT', 'macosx')
          target2.build_configuration_list.set_setting('IPHONEOS_DEPLOYMENT_TARGET', '10.6')

          target_definition = Podfile::TargetDefinition.new(:default, nil)
          user_targets = [target1, target2]
          e = lambda { @analyzer.send(:compute_platform_for_target_definition, target_definition, user_targets) }.should.raise Informative
          e.message.should.match /Targets with different platforms/
        end
      end

      #--------------------------------------#

      describe '#sources' do
        describe 'when there are no explicit sources' do
          it 'defaults to all sources' do
            @analyzer.send(:sources).map(&:url).should ==
              SourcesManager.all.map(&:url)
          end

          it 'prints a warning about the deprecation of implicit sources' do
            @analyzer.send(:sources)
            UI.warnings.should.match /implicit(.+)sources(.+)deprecated/
          end

          it 'prints a warning about how to add explicit sources' do
            @analyzer.send(:sources)
            UI.warnings.should.
              match %r{source 'https://github.com/CocoaPods/Specs.git'}
          end
        end

        describe 'when there are explicit sources' do
          it 'raises if no specs repo with that URL could be added' do
            podfile = Podfile.new do
              source 'not-a-git-repo'
            end
            @analyzer.instance_variable_set(:@podfile, podfile)
            should.raise Informative do
              @analyzer.send(:sources)
            end.message.should.match /Unable to add/
          end

          it 'fetches a specs repo that is specified by the podfile' do
            podfile = Podfile.new do
              source 'https://github.com/artsy/Specs.git'
            end
            @analyzer.instance_variable_set(:@podfile, podfile)
            SourcesManager.expects(:find_or_create_source_with_url).once
            @analyzer.send(:sources)
          end
        end
      end
    end
  end
end
