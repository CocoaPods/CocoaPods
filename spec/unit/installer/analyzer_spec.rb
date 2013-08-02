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
  hash['PODS'] = ["JSONKit (1.4)", "NUI (0.2.0)", "SVPullToRefresh (0.4)"]
  hash['DEPENDENCIES'] = ["JSONKit", "NUI", "SVPullToRefresh"]
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

    describe "Analysis" do

      it "returns whether an installation should be performed" do
        @analyzer.needs_install?.should.be.true
      end

      it "returns whether the Podfile has changes" do
        analysis_result = @analyzer.analyze(false)
        @analyzer.podfile_needs_install?(analysis_result).should.be.true
      end

      it "returns whether the sandbox is not in sync with the lockfile" do
        analysis_result = @analyzer.analyze(false)
        @analyzer.sandbox_needs_install?(analysis_result).should.be.true
      end

      #--------------------------------------#

      it "computes the state of the Podfile respect to the Lockfile" do
        state = @analyzer.analyze.podfile_state
        state.added.should     == ["AFNetworking", "libextobjc"]
        state.changed.should   == ["JSONKit"]
        state.unchanged.should == ["SVPullToRefresh"]
        state.deleted.should   == ["NUI"]
      end

      #--------------------------------------#

      it "updates the repositories by default" do
        config.skip_repo_update = false
        SourcesManager.expects(:update).once
        @analyzer.analyze
      end

      it "does not updates the repositories if config indicates to skip them" do
        config.skip_repo_update = true
        SourcesManager.expects(:update).never
        @analyzer.analyze
      end

      #--------------------------------------#

      it "generates the libraries which represent the target definitions" do
        target = @analyzer.analyze.targets.first
        target.pod_targets.map(&:name).sort.should == [
          'Pods-JSONKit',
          'Pods-AFNetworking',
          'Pods-SVPullToRefresh',
          'Pods-libextobjc'
        ].sort

        target.user_project_path.to_s.should.include 'SampleProject/SampleProject'
        target.client_root.to_s.should.include 'SampleProject'
        target.user_target_uuids.should == ["A346496C14F9BE9A0080D870"]
        user_proj = Xcodeproj::Project.new(target.user_project_path)
        user_proj.objects_by_uuid[target.user_target_uuids.first].name.should == 'SampleProject'
        target.user_build_configurations.should == {"Test"=>:release, "App Store"=>:release}
        target.platform.to_s.should == 'iOS 6.0'
      end

      it "generates the integration library appropriately if the installation will not integrate" do
        config.integrate_targets = false
        target = @analyzer.analyze.targets.first

        target.client_root.should == config.installation_root
        target.user_target_uuids.should == []
        target.user_build_configurations.should == {}
        target.platform.to_s.should == 'iOS 6.0'
      end

      #--------------------------------------#

      it "locks the version of the dependencies which did not change in the Podfile" do
        @analyzer.analyze
        @analyzer.send(:locked_dependencies).map(&:to_s).should == ["SVPullToRefresh (= 0.4)"]
      end

      it "does not lock the dependencies in update mode" do
        @analyzer.update_mode = true
        @analyzer.analyze
        @analyzer.send(:locked_dependencies).map(&:to_s).should == []
      end

      #--------------------------------------#

      it "fetches the dependencies with external sources" do
        podfile_state = Installer::Analyzer::SpecsState.new
        podfile_state.added << "BananaLib"
        @analyzer.stubs(:result).returns(stub(:podfile_state => podfile_state))
        @podfile.stubs(:dependencies).returns([Dependency.new('BananaLib', :git => "example.com")])
        ExternalSources::GitSource.any_instance.expects(:fetch)
        @analyzer.send(:fetch_external_sources)
      end

      xit "it fetches the specification from either the sandbox or from the remote be default" do
        dependency = Dependency.new('Name', :git => 'www.example.com')
        ExternalSources::GitSource.any_instance.expects(:specification_from_external).returns(Specification.new).once
        @resolver.send(:set_from_external_source, dependency)
      end

      xit "it fetches the specification from the remote if in update mode" do
        dependency = Dependency.new('Name', :git => 'www.example.com')
        ExternalSources::GitSource.any_instance.expects(:specification).returns(Specification.new).once
        @resolver.update_external_specs = false
        @resolver.send(:set_from_external_source, dependency)
      end

      xit "it fetches the specification only from the sandbox if pre-downloads are disabled" do
        dependency = Dependency.new('Name', :git => 'www.example.com')
        Sandbox.any_instance.expects(:specification).returns(Specification.new).once
        @resolver.allow_pre_downloads = true
        @resolver.send(:set_from_external_source, dependency)
      end

      #--------------------------------------#

      it "resolves the dependencies" do
        @analyzer.analyze.specifications.map(&:to_s).should == [
          "AFNetworking (1.0.1)",
          "JSONKit (1.5pre)",
          "SVPullToRefresh (0.4)",
          "libextobjc/EXTKeyPathCoding (0.2.3)"
        ]
      end

      xit "removes the specifications of the changed pods to prevent confusion in the resolution process" do
        @analyzer.allow_pre_downloads = true
        podspec = @analyzer.sandbox.root + 'Local Podspecs/JSONKit.podspec'
        podspec.dirname.mkpath
        File.open(podspec, "w") { |f| f.puts('test') }
        @analyzer.analyze
        podspec.should.not.exist?
      end

      it "adds the specifications to the correspondent libraries" do
        @analyzer.analyze.targets.first.pod_targets.map(&:specs).flatten.map(&:to_s).should == [
          "AFNetworking (1.0.1)",
          "JSONKit (1.5pre)",
          "SVPullToRefresh (0.4)",
          "libextobjc/EXTKeyPathCoding (0.2.3)"
        ]
      end

      #--------------------------------------#

      it "computes the state of the Sandbox respect to the resolved dependencies" do
        @analyzer.stubs(:lockfile).returns(nil)
        state = @analyzer.analyze.sandbox_state
        state.added.sort.should == ["AFNetworking", "JSONKit", "SVPullToRefresh", "libextobjc"]
      end

    end

    #-------------------------------------------------------------------------#

  end
end
