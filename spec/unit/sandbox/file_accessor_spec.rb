require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe FileAccessor = Sandbox::FileAccessor do
    before do
      @root = fixture('banana-lib')
      @path_list = Sandbox::PathList.new(@root)
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @spec_consumer = @spec.consumer(:ios)
      @accessor = FileAccessor.new(@path_list, @spec_consumer)
    end

    describe 'In general' do
      it 'raises if the consumer is nil' do
        e = lambda { FileAccessor.new(@path_list, nil) }.should.raise Informative
        e.message.should.match /without a specification consumer/
      end

      it 'raises if the root does not exits' do
        root = temporary_directory + 'missing_folder'
        path_list = Sandbox::PathList.new(root)
        file_accessor = FileAccessor.new(path_list, @spec_consumer)
        e = lambda { file_accessor.source_files }.should.raise Informative
        e.message.should.match /non existent folder/
      end

      it 'returns the root' do
        @accessor.root.should == @path_list.root
      end

      it 'returns the specification' do
        @accessor.spec.should == @spec
      end

      it 'returns the platform for which the spec is being consumed' do
        @accessor.platform_name.should == :ios
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Returning files' do
      it 'returns the source files' do
        @accessor.source_files.sort.should == [
          @root + 'Classes/Banana.h',
          @root + 'Classes/Banana.m',
          @root + 'Classes/BananaPrivate.h',
          @root + 'Classes/BananaTrace.d',
          @root + 'framework/Source/MoreBanana.h',
        ]
      end

      it 'returns the source files that use arc' do
        @accessor.arc_source_files.sort.should == [
          @root + 'Classes/Banana.h',
          @root + 'Classes/Banana.m',
          @root + 'Classes/BananaPrivate.h',
          @root + 'Classes/BananaTrace.d',
          @root + 'framework/Source/MoreBanana.h',
        ]
      end

      it 'returns the source files that do not use arc' do
        @accessor.non_arc_source_files.sort.should == []
      end

      it 'returns the header files' do
        @accessor.headers.sort.should == [
          @root + 'Classes/Banana.h',
          @root + 'Classes/BananaPrivate.h',
          @root + 'framework/Source/MoreBanana.h',
        ]
      end

      it 'returns the public headers' do
        @accessor.public_headers.sort.should == [
          @root + 'Classes/Banana.h',
          @root + 'framework/Source/MoreBanana.h',
        ]
      end

      it 'returns all the headers if no public headers are defined' do
        @spec_consumer.stubs(:public_header_files).returns([])
        @accessor.public_headers.sort.should == [
          @root + 'Classes/Banana.h',
          @root + 'Classes/BananaPrivate.h',
          @root + 'framework/Source/MoreBanana.h',
        ]
      end

      it 'filters the private headers from the public headers' do
        @spec_consumer.stubs(:public_header_files).returns([])
        @spec_consumer.stubs(:private_header_files).returns(['**/*Private*'])
        @accessor.public_headers.sort.should == [
          @root + 'Classes/Banana.h',
          @root + 'framework/Source/MoreBanana.h',
        ]
      end

      it 'includes the vendored framework headers if requested' do
        @accessor.public_headers(true).sort.should == [
          @root + 'Bananalib.framework/Versions/A/Headers/Bananalib.h',
          @root + 'Bananalib.framework/Versions/A/Headers/SubDir/SubBananalib.h',
          @root + 'Classes/Banana.h',
          @root + 'framework/Source/MoreBanana.h',
        ]
      end

      it 'returns the resources' do
        @accessor.resources.sort.should == [
          @root + 'Resources/Images.xcassets',
          @root + 'Resources/logo-sidebar.png',
          @root + 'Resources/sub_dir',
        ]
      end

      it 'includes folders in the resources' do
        @accessor.resources.should.include?(@root + 'Resources/sub_dir')
      end

      it 'returns the preserve paths' do
        @accessor.preserve_paths.sort.should == [
          @root + 'preserve_me.txt',
        ]
      end

      it 'includes folders in the preserve paths' do
        @spec_consumer.stubs(:preserve_paths).returns(['Resources'])
        @accessor.preserve_paths.should.include?(@root + 'Resources')
      end

      it 'returns the paths of the framework bundles' do
        @accessor.vendored_frameworks.should.include?(@root + 'Bananalib.framework')
      end

      it 'returns the paths of the framework headers' do
        @accessor.vendored_frameworks_headers.should == [
          @root + 'Bananalib.framework/Versions/A/Headers/Bananalib.h',
          @root + 'Bananalib.framework/Versions/A/Headers/SubDir/SubBananalib.h',
        ]
      end

      it 'handles when the framework headers directory does not exist' do
        Pathname.any_instance.stubs(:directory?).returns(false)
        FileAccessor.vendored_frameworks_headers_dir(@root + 'Bananalib.framework').should == @root + 'Bananalib.framework/Headers'
      end

      it 'returns the paths of the library files' do
        @accessor.vendored_libraries.should.include?(@root + 'libBananalib.a')
      end

      it 'returns the resource bundles of the pod' do
        @spec_consumer.stubs(:resource_bundles).returns('BananaLib' => 'Resources/*')
        resource_paths = [
          @root + 'Resources/logo-sidebar.png',
          @root + 'Resources/Images.xcassets',
          @root + 'Resources/sub_dir',
        ]
        @accessor.resource_bundles.should == { 'BananaLib' => resource_paths }
      end

      it 'returns the paths of the files of the resource bundles' do
        @spec_consumer.stubs(:resource_bundles).returns('BananaLib' => 'Resources/*')
        resource_paths = [
          @root + 'Resources/logo-sidebar.png',
          @root + 'Resources/Images.xcassets',
          @root + 'Resources/sub_dir',
        ]
        @accessor.resource_bundle_files.should == resource_paths
      end

      it 'takes into account exclude_files when creating the resource bundles of the pod' do
        @spec_consumer.stubs(:exclude_files).returns(['**/*.png'])
        @spec_consumer.stubs(:resource_bundles).returns('BananaLib' => 'Resources/*')
        resource_paths = [
          @root + 'Resources/Images.xcassets',
          @root + 'Resources/sub_dir',
        ]
        @accessor.resource_bundles.should == { 'BananaLib' => resource_paths }
      end

      it 'returns the prefix header of the specification' do
        @accessor.prefix_header.should == @root + 'Classes/BananaLib.pch'
      end

      it 'returns the README file of the specification' do
        @accessor.readme.should == @root + 'README'
      end

      it 'returns the license file of the specification' do
        @accessor.license.should == @root + 'LICENSE'
      end

      #--------------------------------------#

      it 'respects the exclude files' do
        @spec_consumer.stubs(:exclude_files).returns(['Classes/BananaPrivate.h'])
        @accessor.source_files.sort.should == [
          @root + 'Classes/Banana.h',
          @root + 'Classes/Banana.m',
          @root + 'Classes/BananaTrace.d',
          @root + 'framework/Source/MoreBanana.h',
        ]
      end

      describe 'using requires_arc' do
        it 'when false returns all source files as non-arc' do
          @spec_consumer.stubs(:requires_arc).returns(false)
          @accessor.non_arc_source_files.should == @accessor.source_files
          @accessor.arc_source_files.should.be.empty?
        end

        it 'when true returns all source files as arc' do
          @spec_consumer.stubs(:requires_arc).returns(true)
          @accessor.arc_source_files.should == @accessor.source_files
          @accessor.non_arc_source_files.should.be.empty?
        end

        it 'when a file pattern returns all source files as arc that match' do
          @spec_consumer.stubs(:requires_arc).returns(['Classes/Banana.m'])
          @accessor.arc_source_files.should == [@root + 'Classes/Banana.m']
          @accessor.non_arc_source_files.sort.should == [
            @root + 'Classes/Banana.h',
            @root + 'Classes/BananaPrivate.h',
            @root + 'Classes/BananaTrace.d',
            @root + 'framework/Source/MoreBanana.h',
          ]
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Private helpers' do
      describe '#paths_for_attribute' do
        it 'takes into account dir patterns and excluded files' do
          file_patterns = ['Classes/*.{h,m,d}', 'Vendor', 'framework/Source/*.h']
          options = {
            :exclude_patterns => ['Classes/**/osx/**/*', 'Resources/**/osx/**/*'],
            :dir_pattern => '*{.m,.mm,.i,.c,.cc,.cxx,.cpp,.c++,.swift,.h,.hh,.hpp,.ipp,.tpp}',
            :include_dirs => false,
          }
          @spec.exclude_files = options[:exclude_patterns]
          @accessor.expects(:expanded_paths).with(file_patterns, options)
          @accessor.send(:paths_for_attribute, :source_files)
        end
      end
    end

    #-------------------------------------------------------------------------#
  end
end
