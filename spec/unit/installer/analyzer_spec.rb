require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::Analyzer do

    before do
      targer_definition = Podfile::TargetDefinition.new("Pods", @podfile)
      targer_definition.set_platform(:ios, '6.0')
      targer_definition.link_with = 'SampleProject'
      targer_definition.user_project_path = fixture('SampleProject/SampleProject.xcodeproj')
      targer_definition.store_pod('JSONKit', '1.5pre')
      targer_definition.store_pod('AFNetworking', '1.0.1')
      targer_definition.store_pod('SVPullToRefresh', '0.4')
      targer_definition.store_pod('libextobjc/EXTKeyPathCoding', '0.2.3')
      @podfile = Podfile.new
      @podfile.root_target_definitions = [targer_definition]

      lockfile_hash = {}
      lockfile_hash['PODS'] = ["JSONKit (1.4)", "NUI (0.2.0)", "SVPullToRefresh (0.4)"]
      lockfile_hash['DEPENDENCIES'] = ["JSONKit", "NUI", "SVPullToRefresh"]
      lockfile_hash['SPEC CHECKSUMS'] = {}
      lockfile_hash['COCOAPODS'] = VERSION
      lockfile = Lockfile.new(lockfile_hash)

      @sut = Installer::Analyzer.new(config.sandbox, @podfile, lockfile)
    end

    #-------------------------------------------------------------------------#

    describe "In general" do
      it "returns whether an installation should be performed" do
        @sut.needs_install?.should.be.true
      end

      it "returns whether the Podfile has changes" do
        analysis_result = @sut.analyze(false)
        @sut.podfile_needs_install?(analysis_result).should.be.true
      end

      it "returns whether the sandbox is not in sync with the lockfile" do
        analysis_result = @sut.analyze(false)
        @sut.sandbox_needs_install?(analysis_result).should.be.true
      end
    end

    #-------------------------------------------------------------------------#

    describe "Analysis steps" do

      it "updates the repositories by default" do
        config.skip_repo_update = false
        SourcesManager.expects(:update).once
        @sut.analyze
      end

      it "does not updates the repositories if config indicates to skip them" do
        config.skip_repo_update = true
        SourcesManager.expects(:update).never
        @sut.analyze
      end

      #--------------------------------------#

      it "computes the state of the Podfile respect to the Lockfile" do
        state = @sut.analyze.podfile_state
        state.added.should     == ["AFNetworking", "libextobjc"]
        state.changed.should   == ["JSONKit"]
        state.unchanged.should == ["SVPullToRefresh"]
        state.deleted.should   == ["NUI"]
      end

      #--------------------------------------#

      it "locks the version of the dependencies which did not change in the Podfile" do
        @sut.analyze
        @sut.send(:locked_dependencies).map(&:to_s).should == ["SVPullToRefresh (= 0.4)"]
      end

      it "does not lock the dependencies in update mode" do
        @sut.update_mode = true
        @sut.analyze
        @sut.send(:locked_dependencies).map(&:to_s).should == []
      end

      #--------------------------------------#

      it "inspects the user project" do
        Podfile::TargetDefinition.any_instance.stubs(:platform)
        @sut.analyze
        target_definitions_data = @sut.send(:target_definitions_data)
        target_definitions_data.keys.map(&:label).should == ['Pods']
        target_definitions_data = target_definitions_data.values.first
        target_definitions_data.platform.to_s.should == 'iOS 5.0'
      end

      #--------------------------------------#

      it "fetches the dependencies with external sources" do
        podfile_state = Installer::Analyzer::PodsState.new
        podfile_state.added << "BananaLib"
        @sut.stubs(:result).returns(stub(:podfile_state => podfile_state))
        @podfile.stubs(:dependencies).returns([Dependency.new('BananaLib', :git => "example.com")])
        ExternalSources::GitSource.any_instance.expects(:fetch).once
        @sut.send(:fetch_external_sources)
      end

      it "doesn't fetch external sources if pre downloads are disabled" do
        @sut.allow_pre_downloads = false
        podfile_state = Installer::Analyzer::PodsState.new
        podfile_state.added << "BananaLib"
        @sut.stubs(:result).returns(stub(:podfile_state => podfile_state))
        @podfile.stubs(:dependencies).returns([Dependency.new('BananaLib', :git => "example.com")])
        ExternalSources::GitSource.any_instance.expects(:fetch).never
        @sut.send(:fetch_external_sources)
      end

      it "it fetches all the specifications with external sources in update mode" do
        podfile_state = Installer::Analyzer::PodsState.new
        podfile_state.unchanged << "BananaLib"
        @sut.stubs(:result).returns(stub(:podfile_state => podfile_state))
        @podfile.stubs(:dependencies).returns([Dependency.new('BananaLib', :git => "example.com")])
        ExternalSources::GitSource.any_instance.expects(:fetch).once
        @sut.send(:fetch_external_sources)
      end

      #--------------------------------------#

      it "resolves the dependencies" do
        @sut.stubs(:locked_dependencies).returns([Dependency.new("SVPullToRefresh", "= 0.4")])
        specs_by_target = @sut.send(:resolve_dependencies)
        specs_by_target.values.flatten.map(&:to_s).sort.should == [
          "AFNetworking (1.0.1)",
          "JSONKit (1.5pre)",
          "SVPullToRefresh (0.4)",
          "libextobjc/EXTKeyPathCoding (0.2.3)"
        ]
      end

      #--------------------------------------#

      it "generates the target according to the information of the target definitions and of the user project" do
        target = @sut.analyze.targets.first
        target.pod_targets.map(&:name).sort.should == [
          'Pods-JSONKit',
          'Pods-AFNetworking',
          'Pods-SVPullToRefresh',
          'Pods-libextobjc'
        ].sort
        target.pod_targets.map(&:platform).uniq.should == [ Platform.new(:ios, '6.0') ]
        target.user_project_path.to_s.should.include 'SampleProject/SampleProject'
        target.client_root.to_s.should.include 'SampleProject'
        target.user_target_uuids.should == ["A346496C14F9BE9A0080D870"]
        user_proj = Xcodeproj::Project.new(target.user_project_path)
        user_proj.objects_by_uuid[target.user_target_uuids.first].name.should == 'SampleProject'
        target.user_build_configurations.should == {"Test"=>:release, "App Store"=>:release}
        target.platform.to_s.should == 'iOS 6.0'
      end

      it "generates targets with default values if the installation should not integrate" do
        config.integrate_targets = false
        target = @sut.analyze.targets.first

        target.client_root.should == config.installation_root
        target.user_target_uuids.should == []
        target.user_build_configurations.should == {}
        target.platform.to_s.should == 'iOS 6.0'
      end

      it "adds the specifications to the correspondent targets" do
        @sut.analyze.targets.first.pod_targets.map(&:specs).flatten.map(&:to_s).should == [
          "AFNetworking (1.0.1)",
          "JSONKit (1.5pre)",
          "SVPullToRefresh (0.4)",
          "libextobjc/EXTKeyPathCoding (0.2.3)"
        ]
      end

      #--------------------------------------#

      it "computes the state of the Sandbox respect to the resolved dependencies" do
        @sut.stubs(:lockfile).returns(nil)
        state = @sut.analyze.sandbox_state
        state.added.sort.should == ["AFNetworking", "JSONKit", "SVPullToRefresh", "libextobjc"]
      end
    end

    #-------------------------------------------------------------------------#

  end
end
