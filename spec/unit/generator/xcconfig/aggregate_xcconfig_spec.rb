require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  module Generator
    module XCConfig
      describe AggregateXCConfig do

        before do
          target = Target.new('Pod')
          target.user_project_path = config.sandbox.root.dirname + 'Project.xcodeproj'
          target.stubs(:platform).returns(:ios)
          target.public_headers_store = config.sandbox.public_headers
          target.user_project_path = config.sandbox.root + '../Project.xcodeproj'
          target.support_files_root = config.sandbox.root
          @sut = AggregateXCConfig.new(target, config.sandbox.root)
        end

        #---------------------------------------------------------------------#

        describe "#generate" do

          it "generates the xcconfig" do
            xcconfig = @sut.generate
            xcconfig.class.should == Xcodeproj::Config
          end

          it "configures the project to load all members that implement Objective-c classes or categories from the static library" do
            xcconfig = @sut.generate
            xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-ObjC'
          end

          it 'does not add the -fobjc-arc to OTHER_LDFLAGS by default as Xcode 4.3.2 does not support it' do
            xcconfig = @sut.generate
            xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include("-fobjc-arc")
          end

          it 'adds the -fobjc-arc to OTHER_LDFLAGS if any pods require arc and the podfile explicitly requires it' do
            @sut.target.set_arc_compatibility_flag = true
            @sut.target.stubs(:spec_consumers).returns([stub( :requires_arc? => true )])
            xcconfig = @sut.generate
            xcconfig.to_hash['OTHER_LDFLAGS'].split(" ").should.include("-fobjc-arc")
          end

          it "sets the PODS_ROOT build variable" do
            xcconfig = @sut.generate
            xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}/Pods'
          end

          it 'adds the sandbox public headers search paths to the xcconfig, with quotes' do
            xcconfig = @sut.generate
            expected = "\"#{config.sandbox.public_headers.search_paths.join('" "')}\""
            xcconfig.to_hash['HEADER_SEARCH_PATHS'].should == expected
          end

          it 'adds the COCOAPODS macro definition' do
            xcconfig = @sut.generate
            xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should.include 'COCOAPODS=1'
          end

          it 'inherits the parent GCC_PREPROCESSOR_DEFINITIONS value' do
            xcconfig = @sut.generate
            xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should.include '$(inherited)'
          end

        end

        #---------------------------------------------------------------------#

        describe "#save_as" do

          it "saves the xcconfig" do
            path = temporary_directory + 'sample.xcconfig'
            @sut.generate
            @sut.save_as(path)
            Xcodeproj::Config.new(path).to_hash['OTHER_LDFLAGS'].should == "-ObjC"
          end

        end

        #---------------------------------------------------------------------#

        describe "Private Helpers" do

          it "returns the path of the pods root relative to the user project" do
            @sut.send(:relative_pods_root).should == '${SRCROOT}/Pods'
          end

        end

        #---------------------------------------------------------------------#

      end
    end
  end
end
