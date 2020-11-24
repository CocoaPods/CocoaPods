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

      it 'returns the source files that do not match expected file extensions' do
        @accessor.other_source_files.sort.should == [
          @root + 'Classes/BananaTrace.d',
        ]
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
          @root + 'BananaFramework.framework/Versions/A/Headers/BananaFramework.h',
          @root + 'BananaFramework.framework/Versions/A/Headers/SubDir/SubBananaFramework.h',
          @root + 'Classes/Banana.h',
          @root + 'framework/Source/MoreBanana.h',
        ]
      end

      it 'returns the resources' do
        @accessor.resources.sort.should == [
          @root + 'Resources/Base.lproj',
          @root + 'Resources/Images.xcassets',
          @root + 'Resources/Migration.xcmappingmodel',
          @root + 'Resources/Sample.rcproject',
          @root + 'Resources/Sample.xcdatamodeld',
          @root + 'Resources/de.lproj',
          @root + 'Resources/en.lproj',
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
        @accessor.vendored_frameworks.should.include?(@root + 'BananaFramework.framework')
      end

      it 'returns the paths of the framework headers' do
        @accessor.vendored_frameworks_headers.sort.should == [
          @root + 'BananaFramework.framework/Versions/A/Headers/BananaFramework.h',
          @root + 'BananaFramework.framework/Versions/A/Headers/SubDir/SubBananaFramework.h',
        ].sort
      end

      it 'handles when the framework headers directory does not exist' do
        Pathname.any_instance.stubs(:directory?).returns(false)
        FileAccessor.vendored_frameworks_headers_dir(@root + 'BananaFramework.framework').should == @root + 'BananaFramework.framework/Headers'
      end

      it 'returns the paths of the library files' do
        @accessor.vendored_libraries.should.include?(@root + 'libBananaStaticLib.a')
      end

      it 'returns the resource bundles of the pod' do
        @spec_consumer.stubs(:resource_bundles).returns('BananaLib' => 'Resources/*')
        resource_paths = [
          @root + 'Resources/logo-sidebar.png',
          @root + 'Resources/Base.lproj',
          @root + 'Resources/de.lproj',
          @root + 'Resources/en.lproj',
          @root + 'Resources/Images.xcassets',
          @root + 'Resources/Migration.xcmappingmodel',
          @root + 'Resources/Sample.rcproject',
          @root + 'Resources/Sample.xcdatamodeld',
          @root + 'Resources/sub_dir',
        ]
        @accessor.resource_bundles.should == { 'BananaLib' => resource_paths }
      end

      it 'returns the paths of the files of the resource bundles' do
        @spec_consumer.stubs(:resource_bundles).returns('BananaLib' => 'Resources/*')
        resource_paths = [
          @root + 'Resources/logo-sidebar.png',
          @root + 'Resources/Base.lproj',
          @root + 'Resources/de.lproj',
          @root + 'Resources/en.lproj',
          @root + 'Resources/Images.xcassets',
          @root + 'Resources/Migration.xcmappingmodel',
          @root + 'Resources/Sample.rcproject',
          @root + 'Resources/Sample.xcdatamodeld',
          @root + 'Resources/sub_dir',
        ]
        @accessor.resource_bundle_files.should == resource_paths
      end

      it 'takes into account exclude_files when creating the resource bundles of the pod' do
        @spec_consumer.stubs(:exclude_files).returns(['**/*.png'])
        @spec_consumer.stubs(:resource_bundles).returns('BananaLib' => 'Resources/*')
        resource_paths = [
          @root + 'Resources/Base.lproj',
          @root + 'Resources/de.lproj',
          @root + 'Resources/en.lproj',
          @root + 'Resources/Images.xcassets',
          @root + 'Resources/Migration.xcmappingmodel',
          @root + 'Resources/Sample.rcproject',
          @root + 'Resources/Sample.xcdatamodeld',
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

      describe '#spec_license' do
        it 'returns the license file of the specification' do
          @accessor.spec_license.should == @root + 'LICENSE'
        end

        it 'does not auto-detect the license' do
          FileUtils.cp(@root + 'LICENSE', @root + 'LICENSE_TEMP')
          @spec_consumer.stubs(:license).returns({})
          @accessor.spec_license.should.be.nil
          FileUtils.rm_f(@root + 'LICENSE_TEMP')
        end

        it 'returns nil if the license file path does not exist' do
          @spec_consumer.stubs(:license).returns(:file => 'MISSING_PATH')
          @accessor.spec_license.should.be.nil
        end
      end

      it 'returns the docs of the specification' do
        @accessor.docs.should == [
          @root + 'docs/guide1.md',
          @root + 'docs/subdir/guide2.md',
        ]
      end

      it 'returns the podspecs of the specification' do
        @accessor.specs.should == [
          @root + 'BananaLib.podspec',
        ]
      end

      it 'returns the matching podspec of the specification' do
        @accessor.stubs(:specs).returns([@root + 'BananaLib.podspec', @root + 'OtherLib.podspec'])
        @accessor.send(:podspec_file).should == @root + 'BananaLib.podspec'
      end

      it 'returns the developer files of the specification' do
        @accessor.developer_files.should == [
          @root + 'Banana.modulemap',
          @root + 'BananaLib.podspec',
          @root + 'Classes/BananaLib.pch',
          @root + 'LICENSE',
          @root + 'README',
          @root + 'docs/guide1.md',
          @root + 'docs/subdir/guide2.md',
        ]
      end

      it 'warns when a LICENSE file is specified but the path does not exist' do
        @spec_consumer.stubs(:license).returns(:file => 'PathThatDoesNotExist/LICENSE')
        @accessor.developer_files.should == [
          @root + 'Banana.modulemap',
          @root + 'BananaLib.podspec',
          @root + 'Classes/BananaLib.pch',
          @root + 'LICENSE', # Found by globbing
          @root + 'README',
          @root + 'docs/guide1.md',
          @root + 'docs/subdir/guide2.md',
        ]
        UI.warnings.should.include "A license was specified in podspec `#{@spec_consumer.name}` but the file does not exist - #{@accessor.root + 'PathThatDoesNotExist/LICENSE'}\n"
      end

      it 'does not return auto-detected developer files when there are multiple podspecs' do
        @accessor.stubs(:specs).returns([@root + 'BananaLib.podspec', @root + 'OtherLib.podspec'])
        @accessor.developer_files.should == [
          @root + 'Banana.modulemap',
          @root + 'BananaLib.podspec',
          @root + 'Classes/BananaLib.pch',
          @root + 'LICENSE',
        ]
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
            :dir_pattern => '*{.m,.mm,.i,.c,.cc,.cxx,.cpp,.c++,.swift,.h,.hh,.hpp,.ipp,.tpp,.hxx,.def,.inl,.inc}',
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
