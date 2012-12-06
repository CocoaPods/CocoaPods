require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe ExternalSources do
    it "returns the instance of appropriate concrete class according to the parameters" do
      git = Dependency.new("Reachability", :git => nil)
      podspec = Dependency.new("Reachability", :podspec => nil)
      local = Dependency.new("Reachability", :local => nil)

      ExternalSources.from_dependency(git).class.should == ExternalSources::GitSource
      ExternalSources.from_dependency(podspec).class.should == ExternalSources::PodspecSource
      ExternalSources.from_dependency(local).class.should == ExternalSources::LocalSource
    end
  end

  describe ExternalSources::AbstractExternalSource do
    xit "returns the name" do end
    xit "returns the params" do end
    xit "returns the compares to another" do end
    xit "returns the specification" do end
    xit "returns the specification from the sandbox if available" do end
    xit "returns the specification fetching it from the external source" do end
  end

  describe ExternalSources::GitSource do
    it "creates a copy of the podspec" do
      dependency = Dependency.new("Reachability", :git => fixture('integration/Reachability'))
      external_source = ExternalSources.from_dependency(dependency)
      external_source.copy_external_source_into_sandbox(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/Reachability.podspec'
      path.should.exist?
    end

    it "marks a LocalPod as downloaded" do
      dependency = Dependency.new("Reachability", :git => fixture('integration/Reachability'))
      external_source = ExternalSources.from_dependency(dependency)
      external_source.copy_external_source_into_sandbox(config.sandbox)
      config.sandbox.predownloaded_pods.should == ["Reachability"]
    end

    xit "returns the description" do end
  end

  describe ExternalSources::PodspecSource do
    it "creates a copy of the podspec" do
      dependency = Dependency.new("Reachability", :podspec => fixture('integration/Reachability/Reachability.podspec').to_s)
      external_source = ExternalSources.from_dependency(dependency)
      external_source.copy_external_source_into_sandbox(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/Reachability.podspec'
      path.should.exist?
    end

    xit "returns the description" do end
  end

  describe ExternalSources::LocalSource do
    it "creates a copy of the podspec" do
      dependency = Dependency.new("Reachability", :local => fixture('integration/Reachability'))
      external_source = ExternalSources.from_dependency(dependency)
      external_source.copy_external_source_into_sandbox(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/Reachability.podspec'
      path.should.exist?
    end

    xit "returns the description" do end
  end
end
