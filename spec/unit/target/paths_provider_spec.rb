require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  class Target
    describe PathsProvider do
      describe "Common Paths" do

        before do
          @sut = PathsProvider.new('Pods-BananaLib', 'Pods/Generated')
          @sut_aggregate = PathsProvider.new('Pods', 'Pods/Generated')
        end

        it "returns the absolute path of the xcconfig file" do
          @sut.xcconfig_path.to_s.should.include 'Pods/Generated/Pods-BananaLib.xcconfig'
          @sut_aggregate.xcconfig_path.to_s.should.include?('Pods/Generated/Pods.xcconfig')
        end


        it "returns the absolute path of the prefix header file" do
          @sut.prefix_header_path.to_s.should.include 'Pods/Generated/Pods-BananaLib-prefix.pch'
          @sut_aggregate.prefix_header_path.to_s.should.include?('Pods/Generated/Pods-prefix.pch')
        end

        it "returns the absolute path of the bridge support file" do
          @sut.bridge_support_path.to_s.should.include 'Pods/Generated/Pods-BananaLib.bridgesupport'
          @sut_aggregate.bridge_support_path.to_s.should.include?('Pods/Generated/Pods.bridgesupport')
        end

        it "returns the absolute path of the public and private xcconfig files" do
          @sut.xcconfig_path.to_s.should.include 'Pods/Generated/Pods-BananaLib.xcconfig'
          @sut.xcconfig_private_path.to_s.should.include 'Pods/Generated/Pods-BananaLib-Private.xcconfig'
        end

      end

      #-----------------------------------------------------------------------#

      describe "Aggregate Target Paths" do

        before do
          @sut = PathsProvider.new('Pods', 'ProjectDir/Pods/Generated')
          @sut.client_root = Pathname.new('ProjectDir')
        end

        it "returns the absolute path of the target header file" do
          @sut.target_environment_header_path.to_s.should.include 'Pods/Generated/Pods-environment.h'
        end

        it "returns the absolute path of the resources script" do
          @sut.copy_resources_script_path.to_s.should.include?('Pods/Generated/Pods-resources.sh')
        end

        it "returns the absolute path of the acknowledgements files without extension" do
          @sut.acknowledgements_basepath.to_s.should.include?('Pods/Generated/Pods-acknowledgements')
        end

        it "returns the path of the resources script relative to the user project" do
          @sut.copy_resources_script_relative_path.should == '${SRCROOT}/Pods/Generated/Pods-resources.sh'
        end

        it "returns the path of the xcconfig file relative to the user project" do
          @sut.xcconfig_relative_path.should == 'Pods/Generated/Pods.xcconfig'
        end

      end

      #-----------------------------------------------------------------------#
    end
  end
end
