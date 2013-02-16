require File.expand_path('../../spec_helper', __FILE__)

module Pod

  describe ExternalSources do
    it "returns the instance of appropriate concrete class according to the parameters" do
      git     = Dependency.new("Reachability", :git     => nil)
      svn     = Dependency.new("Reachability", :svn     => nil)
      podspec = Dependency.new("Reachability", :podspec => nil)
      local   = Dependency.new("Reachability", :local   => nil)

      ExternalSources.from_dependency(git).class.should     == ExternalSources::GitSource
      ExternalSources.from_dependency(svn).class.should     == ExternalSources::SvnSource
      ExternalSources.from_dependency(podspec).class.should == ExternalSources::PodspecSource
      ExternalSources.from_dependency(local).class.should   == ExternalSources::LocalSource
    end
  end

  #---------------------------------------------------------------------------#

  describe ExternalSources::AbstractExternalSource do

    before do
      dependency = Dependency.new("Reachability", :git => fixture('integration/Reachability'))
      @external_source = ExternalSources.from_dependency(dependency)
    end

    #--------------------------------------#

    describe "In general" do

      it "compares to another" do
        dependency_1 = Dependency.new("Reachability", :git => 'url')
        dependency_2 = Dependency.new("Another_name", :git => 'url')
        dependency_3 = Dependency.new("Reachability", :git => 'another_url')

        dependency_1.should.be == dependency_1
        dependency_1.should.not.be == dependency_2
        dependency_1.should.not.be == dependency_3
      end

      it "returns the specification from the sandbox if available" do
        config.sandbox.store_podspec('Reachability', fixture('integration/Reachability/Reachability.podspec'))
        @external_source.expects(:specification_from_external).never
        @external_source.specification(config.sandbox).name.should == 'Reachability'
      end

      it "fetches the remote if needed to return the specification" do
        @external_source.specification(config.sandbox).name.should == 'Reachability'
      end

      it "returns the specification as stored in the sandbox if available" do
        @external_source.specification_from_external(config.sandbox)
        @external_source.specification_from_local(config.sandbox).name.should == 'Reachability'
      end

      it "returns nil if the specification requested from local is not available in the sandbox" do
        @external_source.specification_from_local(config.sandbox).should.be.nil
      end

      it "returns the specification fetching it from the external source in any case" do
        @external_source.specification_from_external(config.sandbox).name.should == 'Reachability'
      end

      it "stores the specification in the sandbox after fetching it from the remote" do
        path = config.sandbox.root + 'Local Podspecs/Reachability.podspec'
        path.should.not.exist?
        @external_source.specification_from_external(config.sandbox).name.should == 'Reachability'
        path = config.sandbox.root + 'Local Podspecs/Reachability.podspec'
        path.should.exist?
      end

    end

    #--------------------------------------#

    describe "Subclasses helpers" do

      it "pre-downloads the Pod and stores the relevant information in the sandbox" do
        sandbox = config.sandbox
        @external_source.send(:pre_download, sandbox)
        path = config.sandbox.root + 'Local Podspecs/Reachability.podspec'
        path.should.exist?
        sandbox.predownloaded_pods.should == ["Reachability"]
        sandbox.checkout_sources.should == {
          "Reachability" => {
            :git => fixture('integration/Reachability'),
            :commit => "4ec575e4b074dcc87c44018cce656672a979b34a"
          }
        }
      end

    end

  end

  #---------------------------------------------------------------------------#

  describe ExternalSources::GitSource do

    before do
      dependency = Dependency.new("Reachability", :git => fixture('integration/Reachability'))
      @external_source = ExternalSources.from_dependency(dependency)
    end

    it "creates a copy of the podspec" do
      @external_source.copy_external_source_into_sandbox(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/Reachability.podspec'
      path.should.exist?
    end

    it "marks a LocalPod as downloaded" do
      @external_source.copy_external_source_into_sandbox(config.sandbox)
      config.sandbox.predownloaded_pods.should == ["Reachability"]
    end

    it "returns the description" do
      @external_source.description.should.match %r|from `.*Reachability`|
    end
  end

  #---------------------------------------------------------------------------#

  describe ExternalSources::SvnSource do

    before do
      dependency = Dependency.new("SvnSource", :svn => "file://#{fixture('subversion-repo/trunk')}")
      @external_source = ExternalSources.from_dependency(dependency)
    end

    it "creates a copy of the podspec" do
      @external_source.copy_external_source_into_sandbox(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/SvnSource.podspec'
      path.should.exist?
    end

    it "marks a LocalPod as downloaded" do
      @external_source.copy_external_source_into_sandbox(config.sandbox)
      config.sandbox.predownloaded_pods.should == ["SvnSource"]
    end

    it "returns the description" do
      @external_source.description.should.match %r|from `.*subversion-repo/trunk`|
    end
  end

  #---------------------------------------------------------------------------#

  describe ExternalSources::MercurialSource do

    before do
      dependency = Dependency.new("MercurialSource", :hg => fixture('mercurial-repo'))
      @external_source = ExternalSources.from_dependency(dependency)
    end

    it "creates a copy of the podspec" do
      @external_source.copy_external_source_into_sandbox(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/MercurialSource.podspec'
      path.should.exist?
    end

    it "marks a LocalPod as downloaded" do
      @external_source.copy_external_source_into_sandbox(config.sandbox)
      config.sandbox.predownloaded_pods.should == ["MercurialSource"]
    end

    it "returns the description" do
      @external_source.description.should.match %r|from `.*/mercurial-repo`|
    end
  end

  #---------------------------------------------------------------------------#

  describe ExternalSources::PodspecSource do

    before do
      podspec_path = fixture('integration/Reachability/Reachability.podspec')
      dependency = Dependency.new("Reachability", :podspec => podspec_path.to_s)
      @external_source = ExternalSources.from_dependency(dependency)
    end

    it "creates a copy of the podspec" do
      @external_source.copy_external_source_into_sandbox(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/Reachability.podspec'
      path.should.exist?
    end

    it "returns the description" do
      @external_source.description.should.match %r|from `.*Reachability/Reachability.podspec`|
    end
  end

  #---------------------------------------------------------------------------#

  describe ExternalSources::LocalSource do

    before do
      podspec_path = fixture('integration/Reachability/Reachability.podspec')
      dependency = Dependency.new("Reachability", :local => fixture('integration/Reachability'))
      @external_source = ExternalSources.from_dependency(dependency)
    end

    it "creates a copy of the podspec" do
      @external_source.copy_external_source_into_sandbox(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/Reachability.podspec'
      path.should.exist?
    end

    it "returns the description" do
      @external_source.description.should.match %r|from `.*integration/Reachability`|
    end

    it "marks the Pod as local in the sandbox" do
      @external_source.copy_external_source_into_sandbox(config.sandbox)
      config.sandbox.local_pods.should == {
        "Reachability" => fixture('integration/Reachability').to_s
      }
    end

  end

  #---------------------------------------------------------------------------#

end
