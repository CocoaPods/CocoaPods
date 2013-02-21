require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Pod::Library do

    describe "In general" do
      before do
        @target_definition = Podfile::TargetDefinition.new(:default, nil)
        @lib = Library.new(@target_definition)
      end

      it "returns the target_definition that generated it" do
        @lib.target_definition.should == @target_definition
      end

      it "returns the label of the target definition" do
        @lib.label.should == 'Pods'
      end

      it "returns its name" do
        @lib.name.should == 'Pods'
      end

      it "returns the name of its product" do
        @lib.product_name.should == 'libPods.a'
      end
    end

    describe "Support files" do
      before do
        @target_definition = Podfile::TargetDefinition.new(:default, nil)
        @lib = Library.new(@target_definition)
        @lib.support_files_root = config.sandbox.root
        @lib.user_project_path  = config.sandbox.root + '../user_project.xcodeproj'
      end

      it "returns the absolute path of the xcconfig file" do
        @lib.xcconfig_path.to_s.should.include?('Pods/Pods.xcconfig')
      end

      it "returns the absolute path of the resources script" do
        @lib.copy_resources_script_path.to_s.should.include?('Pods/Pods-resources.sh')
      end

      it "returns the absolute path of the target header file" do
        @lib.target_header_path.to_s.should.include?('Pods/Pods-header.h')
      end

      it "returns the absolute path of the prefix header file" do
        @lib.prefix_header_path.to_s.should.include?('Pods/Pods-prefix.pch')
      end

      it "returns the absolute path of the bridge support file" do
        @lib.bridge_support_path.to_s.should.include?('Pods/Pods.bridgesupport')
      end

      it "returns the absolute path of the acknowledgements files without extension" do
        @lib.acknowledgements_basepath.to_s.should.include?('Pods/Pods-acknowledgements')
      end

      #--------------------------------------#

      it "returns the path of the resources script relative to the user project" do
        @lib.copy_resources_script_relative_path.should == '${SRCROOT}/Pods/Pods-resources.sh'
      end

      it "returns the path of the xcconfig file relative to the user project" do
        @lib.xcconfig_relative_path.should == 'Pods/Pods.xcconfig'
      end

    end
  end
end
