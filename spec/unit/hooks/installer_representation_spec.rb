require File.expand_path('../../../spec_helper', __FILE__)

def safe_stub(object, method, return_value = nil)
  object.should.respond_to(method)
  object.expects(method).returns(return_value)
end

module Pod
  describe Hooks::InstallerRepresentation do

    before do
      podfile = Pod::Podfile.new do
        platform :ios
        pod 'JSONKit'
      end
      config.integrate_targets = false
      @installer = Installer.new(config.sandbox, podfile)
      @installer.send(:analyze)
      @spec = @installer.targets.first.libraries.map(&:spec).first
      @installer.stubs(:installed_specs).returns(@specs)
      @rep = Hooks::InstallerRepresentation.new(@installer)
    end

    #-------------------------------------------------------------------------#

    describe "Public Hooks API" do

      it "returns the sandbox root" do
        @rep.sandbox_root.should == config.sandbox.root
      end

      it "returns the pods project" do
        project = stub()
        safe_stub(@installer, :pods_project, project)
        @rep.project.should == project
      end

      it "the hook representation of the pods" do
        @rep.pods.map(&:name).should == ['JSONKit']
      end

      it "the hook representation of the libraries" do
        @rep.libraries.map(&:name).sort.should == ['Pods', 'Pods-JSONKit'].sort
      end

      it "returns the specs by library representation" do
        specs_by_lib = @rep.specs_by_lib
        lib_rep = specs_by_lib.keys.first
        lib_rep.name.should == 'Pods-JSONKit'
        specs_by_lib.should == { lib_rep => @spec }
      end

      it "returns the pods representation by library representation" do
        pods_by_lib = @rep.pods_by_lib
        target_definition = @installer.targets.first.libraries.first.target_definition
        pods_by_lib[target_definition].map(&:name).should == ['JSONKit']
      end

    end

    #-------------------------------------------------------------------------#

    describe "Unsafe Hooks API" do

      it "returns the sandbox" do
        @rep.sandbox.should == config.sandbox
      end

      it "returns the config" do
        @rep.config.should == config
      end

      it "returns the installer" do
        @rep.installer.should == @installer
      end

    end

    #-------------------------------------------------------------------------#

  end
end
