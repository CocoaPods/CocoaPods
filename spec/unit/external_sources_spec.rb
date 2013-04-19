require File.expand_path('../../spec_helper', __FILE__)

module Pod

  describe ExternalSources do
    it "returns the instance of appropriate concrete class according to the parameters" do
      git     = Dependency.new("Reachability", :git     => nil)
      svn     = Dependency.new("Reachability", :svn     => nil)
      podspec = Dependency.new("Reachability", :podspec => nil)
      local   = Dependency.new("Reachability", :local   => nil)
      path    = Dependency.new("Reachability", :path   => nil)

      ExternalSources.from_dependency(git, nil).class.should     == ExternalSources::GitSource
      ExternalSources.from_dependency(svn, nil).class.should     == ExternalSources::SvnSource
      ExternalSources.from_dependency(podspec, nil).class.should == ExternalSources::PodspecSource
      ExternalSources.from_dependency(local, nil).class.should   == ExternalSources::PathSource
      ExternalSources.from_dependency(path, nil).class.should    == ExternalSources::PathSource
    end
  end

  #---------------------------------------------------------------------------#

  describe ExternalSources::AbstractExternalSource do

    before do
      dependency = Dependency.new("Reachability", :git => fixture('integration/Reachability'))
      @external_source = ExternalSources.from_dependency(dependency, nil)
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

      it "fetches the specification from the remote stores it in the sandbox" do
        config.sandbox.specification('Reachability').should == nil
        @external_source.fetch(config.sandbox)
        config.sandbox.specification('Reachability').name.should == 'Reachability'
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
      @external_source = ExternalSources.from_dependency(dependency, nil)
    end

    it "creates a copy of the podspec" do
      @external_source.fetch(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/Reachability.podspec'
      path.should.exist?
    end

    it "marks a LocalPod as downloaded" do
      @external_source.fetch(config.sandbox)
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
      @external_source = ExternalSources.from_dependency(dependency, nil)
    end

    it "creates a copy of the podspec" do
      @external_source.fetch(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/SvnSource.podspec'
      path.should.exist?
    end

    it "marks a LocalPod as downloaded" do
      @external_source.fetch(config.sandbox)
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
      @external_source = ExternalSources.from_dependency(dependency, nil)
    end

    it "creates a copy of the podspec" do
      @external_source.fetch(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/MercurialSource.podspec'
      path.should.exist?
    end

    it "marks a LocalPod as downloaded" do
      @external_source.fetch(config.sandbox)
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
      podfile_path = fixture('integration/Podfile')
      @external_source = ExternalSources.from_dependency(dependency, podfile_path)
    end

    it "creates a copy of the podspec" do
      @external_source.fetch(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/Reachability.podspec'
      path.should.exist?
    end

    it "returns the description" do
      @external_source.description.should.match %r|from `.*Reachability/Reachability.podspec`|
    end

    describe "Helpers" do

      it "handles absolute paths" do
        @external_source.stubs(:params).returns(:podspec => fixture('integration/Reachability'))
        path = @external_source.send(:podspec_uri)
        path.should == fixture('integration/Reachability/Reachability.podspec').to_s
      end

      it "handles paths when there is no podfile path" do
        @external_source.stubs(:podfile_path).returns(nil)
        @external_source.stubs(:params).returns(:podspec => fixture('integration/Reachability'))
        path = @external_source.send(:podspec_uri)
        path.should == fixture('integration/Reachability/Reachability.podspec').to_s
      end

      it "handles relative paths" do
        @external_source.stubs(:params).returns(:podspec => 'Reachability')
        path = @external_source.send(:podspec_uri)
        path.should == fixture('integration/Reachability/Reachability.podspec').to_s
      end

      it "expands the tilde" do
        @external_source.stubs(:params).returns(:podspec => '~/Reachability')
        path = @external_source.send(:podspec_uri)
        path.should == ENV['HOME'] + '/Reachability/Reachability.podspec'
      end

      it "handles urls" do
        @external_source.stubs(:params).returns(:podspec => "http://www.example.com/Reachability.podspec")
        path = @external_source.send(:podspec_uri)
        path.should == "http://www.example.com/Reachability.podspec"
      end
    end
  end

  #---------------------------------------------------------------------------#

  describe ExternalSources::PathSource do

    before do
      podspec_path = fixture('integration/Reachability/Reachability.podspec')
      dependency = Dependency.new("Reachability", :path => fixture('integration/Reachability'))
      podfile_path = fixture('integration/Podfile')
      @external_source = ExternalSources.from_dependency(dependency, podfile_path)
    end

    it "creates a copy of the podspec" do
      @external_source.fetch(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/Reachability.podspec'
      path.should.exist?
    end

    it "creates a copy of the podspec [Deprecated local option]" do
      dependency = Dependency.new("Reachability", :local => fixture('integration/Reachability'))
      podfile_path = fixture('integration/Podfile')
      external_source = ExternalSources.from_dependency(dependency, podfile_path)
      external_source.fetch(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/Reachability.podspec'
      path.should.exist?
    end

    it "returns the description" do
      @external_source.description.should.match %r|from `.*integration/Reachability`|
    end

    it "marks the Pod as local in the sandbox" do
      @external_source.fetch(config.sandbox)
      config.sandbox.local_pods.should == {
        "Reachability" => fixture('integration/Reachability').to_s
      }
    end

    describe "Helpers" do

      it "handles absolute paths" do
        @external_source.stubs(:params).returns(:path => fixture('integration/Reachability'))
        path = @external_source.send(:podspec_path)
        path.should == fixture('integration/Reachability/Reachability.podspec')
      end

      it "handles paths when there is no podfile path" do
        @external_source.stubs(:podfile_path).returns(nil)
        @external_source.stubs(:params).returns(:path => fixture('integration/Reachability'))
        path = @external_source.send(:podspec_path)
        path.should == fixture('integration/Reachability/Reachability.podspec')
      end

      it "handles relative paths" do
        @external_source.stubs(:params).returns(:path => 'Reachability')
        path = @external_source.send(:podspec_path)
        path.should == fixture('integration/Reachability/Reachability.podspec')
      end

      it "expands the tilde" do
        @external_source.stubs(:params).returns(:path => '~/Reachability')
        Pathname.any_instance.stubs(:exist?).returns(true)
        path = @external_source.send(:podspec_path)
        path.should == Pathname(ENV['HOME']) + 'Reachability/Reachability.podspec'
      end

      it "raises if the podspec cannot be found" do
        @external_source.stubs(:params).returns(:path => temporary_directory)
        e = lambda { @external_source.send(:podspec_path) }.should.raise Informative
        e.message.should.match /No podspec found/
      end
    end
  end

  #---------------------------------------------------------------------------#

end
