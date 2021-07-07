require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Sandbox::PodDirCleaner do
    before do
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      specs_by_platform = { :ios => [@spec] }
      @root = temporary_directory + 'BananaLib'
      Downloader.for_target(@root, :git => SpecHelper.fixture('banana-lib')).download
      @cleaner = Sandbox::PodDirCleaner.new(@root, specs_by_platform)
    end

    it 'returns the clean paths' do
      paths = @cleaner.send(:clean_paths)
      relative_paths = paths.map { |p| p.gsub("#{@root}/", '') }

      # Because there are thousands of files inside .git/, we're excluding
      # them from the comparison.
      paths_without_git = relative_paths.reject { |p| p.include? '.git/' }

      paths_without_git.sort.should == %w(
        .git
        .gitmodules
        BananaLib.podspec
        docs
        docs/guide1.md
        docs/subdir
        docs/subdir/guide2.md
        libPusher
        sub-dir
        sub-dir/sub-dir-2
        sub-dir/sub-dir-2/somefile.txt
      )
    end

    it 'returns the used files' do
      paths = @cleaner.send(:used_files)
      relative_paths = paths.map { |p| p.gsub("#{@root}/", '') }
      relative_paths.sort.should == %w(
        Banana.modulemap
        BananaFramework.framework
        Classes/Banana.h
        Classes/Banana.m
        Classes/BananaLib.pch
        Classes/BananaPrivate.h
        Classes/BananaTrace.d
        LICENSE
        README
        Resources/Base.lproj
        Resources/Images.xcassets
        Resources/Migration.xcmappingmodel
        Resources/Sample.rcproject
        Resources/Sample.xcdatamodeld
        Resources/de.lproj
        Resources/en.lproj
        Resources/logo-sidebar.png
        Resources/sub_dir
        framework/Source/MoreBanana.h
        libBananaStaticLib.a
        preserve_me.txt
      )
    end

    it 'handles Pods with multiple file accessors' do
      spec = fixture_spec('banana-lib/BananaLib.podspec')
      spec.source = { :git => SpecHelper.fixture('banana-lib') }
      spec.source_files = []
      spec.ios.source_files = 'Classes/*.h'
      spec.osx.source_files = 'Classes/*.m'
      ios_spec = spec.dup
      osx_spec = spec.dup
      specs_by_platform = { :ios => [ios_spec], :osx => [osx_spec] }
      @cleaner = Sandbox::PodDirCleaner.new(@root, specs_by_platform)
      paths = @cleaner.send(:used_files)
      relative_paths = paths.map { |p| p.gsub("#{@root}/", '') }
      relative_paths.sort.should == %w(
        Banana.modulemap
        BananaFramework.framework
        Classes/Banana.h
        Classes/Banana.m
        Classes/BananaLib.pch
        Classes/BananaPrivate.h
        LICENSE
        README
        Resources/Base.lproj
        Resources/Images.xcassets
        Resources/Migration.xcmappingmodel
        Resources/Sample.rcproject
        Resources/Sample.xcdatamodeld
        Resources/de.lproj
        Resources/en.lproj
        Resources/logo-sidebar.png
        Resources/sub_dir
        libBananaStaticLib.a
        preserve_me.txt
      )
    end

    it 'compacts the used files as nil would be converted to the empty string' do
      Sandbox::FileAccessor.any_instance.stubs(:license)
      Sandbox::FileAccessor.any_instance.stubs(:module_map)
      Sandbox::FileAccessor.any_instance.stubs(:prefix_header)
      Sandbox::FileAccessor.any_instance.stubs(:preserve_paths)
      Sandbox::FileAccessor.any_instance.stubs(:readme)
      Sandbox::FileAccessor.any_instance.stubs(:resources).returns(nil)
      Sandbox::FileAccessor.any_instance.stubs(:source_files)
      Sandbox::FileAccessor.any_instance.stubs(:vendored_frameworks)
      Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries)
      paths = @cleaner.send(:used_files)
      paths.should == []
    end
  end
end
