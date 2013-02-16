require File.expand_path('../../../spec_helper', __FILE__)

# Stubs an object ensuring that it responds to the given method
#
def safe_stub(object, method, return_value)
  object.should.respond_to?(method)
  object.stubs(method).returns(return_value)
end

module Pod
  describe Hooks::InstallerData do

    before do
      target_definition_1 = Podfile::TargetDefinition.new('target_1', nil, nil)
      target_definition_2 = Podfile::TargetDefinition.new('target_2', nil, nil)
      lib_1 = Library.new(target_definition_1)
      lib_2 = Library.new(target_definition_2)
      spec_1 = Spec.new(nil, 'Spec_1')
      spec_2 = Spec.new(nil, 'Spec_2')
      lib_1.specs = [spec_1]
      lib_2.specs = [spec_2]
      pods_project = Pod::Project.new(config.sandbox.project_path)

      @installer = Installer.new(config.sandbox, nil, nil)
      safe_stub(@installer, :pods_project, pods_project)
      safe_stub(@installer, :libraries, [lib_1, lib_2])

      @installer_data = Hooks::InstallerData.new(@installer)
    end

    #-------------------------------------------------------------------------#

    describe "Public Hooks API" do

      it "returns the sandbox root" do
        @installer_data.sandbox.root.should == temporary_directory + 'Pods'
      end

      it "returns the pods project" do
        @installer_data.project.class.should == Pod::Project
      end

      it "returns the pods data" do
        @installer_data.pods.map(&:name).should == ["Spec_1", "Spec_2"]
      end

      it "returns the target installers data" do
        names = @installer_data.target_installers.map { |ti_data| ti_data.target_definition.name  }
        names.should == ["target_1", "target_2"]
      end

      it "returns the specs by target" do
        specs_by_target = @installer_data.specs_by_target
        names = {}
        specs_by_target.each do |target, specs|
          names[target.name] = specs.map(&:name)
        end
        names.should == {"target_1"=>["Spec_1"], "target_2"=>["Spec_2"]}
      end

      it "returns the pods data grouped by target definition data" do
        pods_by_target = @installer_data.pods_by_target
        names = {}
        pods_by_target.each do |target, pods_data|
          names[target.name] = pods_data.map(&:name)
        end
        names.should == {"target_1"=>["Spec_1"], "target_2"=>["Spec_2"]}
      end

    end

    #-------------------------------------------------------------------------#

    describe "Unsafe Hooks API" do

      it "returns the sandbox" do
        @installer_data.sandbox.should == config.sandbox
      end

      it "returns the config" do
        @installer_data.config.should == Config.instance
      end

    end

    #-------------------------------------------------------------------------#

  end
end
