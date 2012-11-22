require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe ExternalSources do
    before do
      @sandbox = temporary_sandbox
    end

    it "marks a LocalPod as downloaded if it's from GitSource" do
      dependency = Dependency.new("Reachability", :git => fixture('integration/Reachability'))
      external_source = ExternalSources.from_dependency(dependency)
      external_source.copy_external_source_into_sandbox(@sandbox, Platform.ios)
      @sandbox.installed_pod_named('Reachability', Platform.ios).downloaded.should.be.true
    end

    it "creates a copy of the podspec (GitSource)" do
      dependency = Dependency.new("Reachability", :git => fixture('integration/Reachability'))
      external_source = ExternalSources.from_dependency(dependency)
      external_source.copy_external_source_into_sandbox(@sandbox, Platform.ios)
      path = @sandbox.root + 'Local Podspecs/Reachability.podspec'
      path.should.exist?
    end

    it "creates a copy of the podspec (PodspecSource)" do
      dependency = Dependency.new("Reachability", :podspec => fixture('integration/Reachability/Reachability.podspec').to_s)
      external_source = ExternalSources.from_dependency(dependency)
      external_source.copy_external_source_into_sandbox(@sandbox, Platform.ios)
      path = @sandbox.root + 'Local Podspecs/Reachability.podspec'
      path.should.exist?
    end

    it "creates a copy of the podspec (LocalSource)" do
      dependency = Dependency.new("Reachability", :local => fixture('integration/Reachability'))
      external_source = ExternalSources.from_dependency(dependency)
      external_source.copy_external_source_into_sandbox(@sandbox, Platform.ios)
      path = @sandbox.root + 'Local Podspecs/Reachability.podspec'
      path.should.exist?
    end
  end
end
