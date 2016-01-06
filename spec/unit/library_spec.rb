require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Pod::AggregateTarget do
    describe 'In general' do
      before do
        @target_definition = Podfile::TargetDefinition.new('Pods', nil)
        @lib = AggregateTarget.new(@target_definition, config.sandbox)
      end

      it 'returns the target_definition that generated it' do
        @lib.target_definition.should == @target_definition
      end

      it 'returns the label of the target definition' do
        @lib.label.should == 'Pods'
      end

      it 'returns its name' do
        @lib.name.should == 'Pods'
      end

      it 'returns the name of its product' do
        @lib.product_name.should == 'libPods.a'
      end
    end

    describe 'Support files' do
      before do
        @target_definition = Podfile::TargetDefinition.new('Pods', nil)
        @lib = AggregateTarget.new(@target_definition, config.sandbox)
        @lib.client_root = config.sandbox.root.dirname
      end

      it 'returns the absolute path of the xcconfig file' do
        @lib.xcconfig_path('Release').to_s.should.include?('Pods/Target Support Files/Pods/Pods.release.xcconfig')
      end

      it 'returns the absolute path of the resources script' do
        @lib.copy_resources_script_path.to_s.should.include?('Pods/Target Support Files/Pods/Pods-resources.sh')
      end

      it 'returns the absolute path of the prefix header file' do
        @lib.prefix_header_path.to_s.should.include?('Pods/Target Support Files/Pods/Pods-prefix.pch')
      end

      it 'returns the absolute path of the bridge support file' do
        @lib.bridge_support_path.to_s.should.include?('Pods/Target Support Files/Pods/Pods.bridgesupport')
      end

      it 'returns the absolute path of the acknowledgements files without extension' do
        @lib.acknowledgements_basepath.to_s.should.include?('Pods/Target Support Files/Pods/Pods-acknowledgements')
      end

      #--------------------------------------#

      it 'returns the path of the resources script relative to the user project' do
        @lib.copy_resources_script_relative_path.should == '${SRCROOT}/Pods/Target Support Files/Pods/Pods-resources.sh'
      end

      it 'returns the path of the xcconfig file relative to the user project' do
        @lib.xcconfig_relative_path('Release').should == 'Pods/Target Support Files/Pods/Pods.release.xcconfig'
      end
    end
  end
end
