require File.expand_path('../../../spec_helper', __FILE__)

module Pod
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

      it "pre-downloads the Pod with a JSON podspec and stores the relevant information in the sandbox" do
        dependency = Dependency.new("Reachability", :git => fixture('integration/Reachability'), :branch => 'json_podspec')
        source = ExternalSources.from_dependency(dependency, nil)
        sandbox = config.sandbox
        source.send(:pre_download, sandbox)
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
end
