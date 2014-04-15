require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe ExternalSources do
    before do
      @subject = ExternalSources
    end

    describe "from_dependency" do
      it "supports a podspec source" do
        dep = Dependency.new("Reachability", :podspec => nil)
        klass = @subject.from_dependency(dep, nil).class
        klass.should == @subject::PodspecSource
      end

      it "supports a path source" do
        dep = Dependency.new("Reachability", :path => nil)
        klass = @subject.from_dependency(dep, nil).class
        klass.should == @subject::PathSource
      end

      it "supports a path source specified with the legacy :local key" do
        dep = Dependency.new("Reachability", :local => nil)
        klass = @subject.from_dependency(dep, nil).class
        klass.should == @subject::PathSource
      end

      it "supports all the strategies implemented by the downloader" do
        [:git, :svn, :hg, :bzr, :http].each do |strategy|
          dep     = Dependency.new("Reachability", strategy => nil)
          klass = @subject.from_dependency(dep, nil).class
          klass.should == @subject::DownloaderSource
        end
      end
    end
  end

  #---------------------------------------------------------------------------#

  describe ExternalSources::AbstractExternalSource do

    before do
      dependency = Dependency.new("Reachability", :git => fixture('integration/Reachability'))
      @subject = ExternalSources.from_dependency(dependency, nil)
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
        @subject.fetch(config.sandbox)
        config.sandbox.specification('Reachability').name.should == 'Reachability'
      end

    end

    #--------------------------------------#

    describe "Subclasses helpers" do

      it "pre-downloads the Pod and stores the relevant information in the sandbox" do
        sandbox = config.sandbox
        @subject.send(:pre_download, sandbox)
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

  describe ExternalSources::DownloaderSource do

    before do
      params = {
        :git => fixture('integration/Reachability'),
        :branch => 'master'
      }
      dep = Dependency.new("Reachability", params)
      @subject = ExternalSources.from_dependency(dep, nil)
    end

    it "creates a copy of the podspec" do
      @subject.fetch(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/Reachability.podspec'
      path.should.exist?
    end

    it "marks the Pod as pre-downloaded" do
      @subject.fetch(config.sandbox)
      config.sandbox.predownloaded_pods.should == ["Reachability"]
    end

    it "returns the description" do
      expected = /from `.*Reachability`, branch `master`/
      @subject.description.should.match(expected)
    end
  end

  #---------------------------------------------------------------------------#

  describe ExternalSources::PodspecSource do

    before do
      podspec_path = fixture('integration/Reachability/Reachability.podspec')
      dependency = Dependency.new("Reachability", :podspec => podspec_path.to_s)
      podfile_path = fixture('integration/Podfile')
      @subject = ExternalSources.from_dependency(dependency, podfile_path)
    end

    it "creates a copy of the podspec" do
      @subject.fetch(config.sandbox)
      path = config.sandbox.root + 'Local Podspecs/Reachability.podspec'
      path.should.exist?
    end

    it "returns the description" do
      @subject.description.should.match %r|from `.*Reachability/Reachability.podspec`|
    end

    describe "Helpers" do

      it "handles absolute paths" do
        @subject.stubs(:params).returns(:podspec => fixture('integration/Reachability'))
        path = @subject.send(:podspec_uri)
        path.should == fixture('integration/Reachability/Reachability.podspec').to_s
      end

      it "handles paths when there is no podfile path" do
        @subject.stubs(:podfile_path).returns(nil)
        @subject.stubs(:params).returns(:podspec => fixture('integration/Reachability'))
        path = @subject.send(:podspec_uri)
        path.should == fixture('integration/Reachability/Reachability.podspec').to_s
      end

      it "handles relative paths" do
        @subject.stubs(:params).returns(:podspec => 'Reachability')
        path = @subject.send(:podspec_uri)
        path.should == fixture('integration/Reachability/Reachability.podspec').to_s
      end

      it "expands the tilde" do
        @subject.stubs(:params).returns(:podspec => '~/Reachability')
        path = @subject.send(:podspec_uri)
        path.should == ENV['HOME'] + '/Reachability/Reachability.podspec'
      end

      it "handles URLs" do
        @subject.stubs(:params).returns(:podspec => "http://www.example.com/Reachability.podspec")
        path = @subject.send(:podspec_uri)
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
      @subject = ExternalSources.from_dependency(dependency, podfile_path)
    end

    it "creates a copy of the podspec" do
      @subject.fetch(config.sandbox)
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
      @subject.description.should.match %r|from `.*integration/Reachability`|
    end

    it "marks the Pod as local in the sandbox" do
      @subject.fetch(config.sandbox)
      config.sandbox.development_pods.should == {
        "Reachability" => fixture('integration/Reachability').to_s
      }
    end

    describe "Helpers" do

      it "handles absolute paths" do
        @subject.stubs(:params).returns(:path => fixture('integration/Reachability'))
        path = @subject.send(:podspec_path)
        path.should == fixture('integration/Reachability/Reachability.podspec')
      end

      it "handles paths when there is no podfile path" do
        @subject.stubs(:podfile_path).returns(nil)
        @subject.stubs(:params).returns(:path => fixture('integration/Reachability'))
        path = @subject.send(:podspec_path)
        path.should == fixture('integration/Reachability/Reachability.podspec')
      end

      it "handles relative paths" do
        @subject.stubs(:params).returns(:path => 'Reachability')
        path = @subject.send(:podspec_path)
        path.should == fixture('integration/Reachability/Reachability.podspec')
      end

      it "expands the tilde" do
        @subject.stubs(:params).returns(:path => '~/Reachability')
        Pathname.any_instance.stubs(:exist?).returns(true)
        path = @subject.send(:podspec_path)
        path.should == Pathname(ENV['HOME']) + 'Reachability/Reachability.podspec'
      end

      it "raises if the podspec cannot be found" do
        @subject.stubs(:params).returns(:path => temporary_directory)
        e = lambda { @subject.send(:podspec_path) }.should.raise Informative
        e.message.should.match /No podspec found for `Reachability` in `#{temporary_directory}`/
      end
    end
  end

  #---------------------------------------------------------------------------#

end
