require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Sandbox::PathList do
    before do
      @path_list = Sandbox::PathList.new(fixture('banana-lib'))
    end

    describe 'In general' do
      it 'creates the list of all the files' do
        files = @path_list.files
        files.reject! do |f|
          f.include?('libPusher') || f.include?('.git') || f.include?('DS_Store')
        end
        expected = %w(
          Banana.modulemap
          BananaFramework.framework/Versions/A/Headers/BananaFramework.h
          BananaFramework.framework/Versions/A/Headers/SubDir/SubBananaFramework.h
          BananaLib.podspec
          Classes/Banana.h
          Classes/Banana.m
          Classes/BananaLib.pch
          Classes/BananaPrivate.h
          Classes/BananaTrace.d
          LICENSE
          README
          Resources/Base.lproj/Main.storyboard
          Resources/Images.xcassets/Logo.imageset/Contents.json
          Resources/Images.xcassets/Logo.imageset/logo.png
          Resources/Migration.xcmappingmodel/xcmapping.xml
          Resources/Sample.rcproject/Library/ProjectLibrary/Contents.json
          Resources/Sample.rcproject/Library/ProjectLibrary/Version.json
          Resources/Sample.rcproject/SceneThumbnails/A6BD9D7A-36EE-4D49-BF83-DEB3039A790C.thumbnails/square
          Resources/Sample.rcproject/SceneThumbnails/A6BD9D7A-36EE-4D49-BF83-DEB3039A790C.thumbnails/wide
          Resources/Sample.rcproject/com.apple.RCFoundation.Project
          Resources/Sample.xcdatamodeld/.xccurrentversion
          Resources/Sample.xcdatamodeld/Sample\ 2.xcdatamodel/contents
          Resources/Sample.xcdatamodeld/Sample.xcdatamodel/contents
          Resources/de.lproj/logo-localized.png
          Resources/en.lproj/Main.strings
          Resources/en.lproj/logo-localized.png
          Resources/en.lproj/nested/logo-nested.png
          Resources/logo-sidebar.png
          Resources/sub_dir/logo-sidebar.png
          docs/guide1.md
          docs/subdir/guide2.md
          framework/Source/MoreBanana.h
          libBananaStaticLib.a
          preserve_me.txt
          sub-dir/sub-dir-2/somefile.txt
        )

        files.sort.should == expected
      end

      it 'creates the list of the directories' do
        dirs = @path_list.dirs
        dirs.reject! do |f|
          f.include?('libPusher') || f.include?('.git')
        end
        dirs.sort.should == %w(
          BananaFramework.framework
          BananaFramework.framework/Headers
          BananaFramework.framework/Versions
          BananaFramework.framework/Versions/A
          BananaFramework.framework/Versions/A/Headers
          BananaFramework.framework/Versions/A/Headers/SubDir
          BananaFramework.framework/Versions/Current
          Classes
          Resources
          Resources/Base.lproj
          Resources/Images.xcassets
          Resources/Images.xcassets/Logo.imageset
          Resources/Migration.xcmappingmodel
          Resources/Sample.rcproject
          Resources/Sample.rcproject/Library
          Resources/Sample.rcproject/Library/ProjectLibrary
          Resources/Sample.rcproject/SceneThumbnails
          Resources/Sample.rcproject/SceneThumbnails/A6BD9D7A-36EE-4D49-BF83-DEB3039A790C.thumbnails
          Resources/Sample.xcdatamodeld
          Resources/Sample.xcdatamodeld/Sample\ 2.xcdatamodel
          Resources/Sample.xcdatamodeld/Sample.xcdatamodel
          Resources/de.lproj
          Resources/en.lproj
          Resources/en.lproj/nested
          Resources/sub_dir
          docs
          docs/subdir
          framework
          framework/Source
          sub-dir
          sub-dir/sub-dir-2
        )
      end

      it 'handles directories with glob metacharacters' do
        root = temporary_directory + '[CP] Test'
        root.mkpath
        FileUtils.touch(root + 'Class.h')
        @path_list = Sandbox::PathList.new(root)
        @path_list.files.should == ['Class.h']
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Globbing' do
      it 'can glob the root for a given pattern' do
        paths = @path_list.relative_glob('Classes/*.{h,m}').map(&:to_s)
        paths.sort.should == %w(
          Classes/Banana.h
          Classes/Banana.m
          Classes/BananaPrivate.h
        )
      end

      it 'can return the absolute paths from glob' do
        paths = @path_list.glob('Classes/*.{h,m}')
        paths.all?(&:absolute?).should == true
      end

      describe 'Symlinked Directory' do
        before do
          @tmpdir = Pathname.new(Dir.mktmpdir)
          FileUtils.copy_entry(@path_list.root.to_s, @tmpdir + 'banana-lib')

          @symlink_dir = @path_list.root.dirname + 'banana-lib-symlinked'
          FileUtils.remove_entry(@symlink_dir) if File.symlink?(@symlink_dir)
        end

        after do
          FileUtils.remove_entry(@tmpdir) if Dir.exist?(@tmpdir)
          FileUtils.remove_entry(@symlink_dir) if File.symlink?(@symlink_dir)
        end

        it 'glob returns the absolute path when root is a symlinked directory' do
          File.symlink(@tmpdir + 'banana-lib', @symlink_dir.to_s)
          @path_list = Sandbox::PathList.new(fixture('banana-lib-symlinked/'))

          paths = @path_list.glob('Classes/*.{h,m}')
          paths.first.realpath.to_s.should.include? @tmpdir.to_s
        end
      end

      it 'can return the relative paths from glob' do
        paths = @path_list.relative_glob('Classes/*.{h,m}')
        paths.any?(&:absolute?).should == false
      end

      it 'supports the `**` glob pattern' do
        paths = @path_list.relative_glob('Classes/**/*.{h,m}').map(&:to_s)
        paths.sort.should == %w(
          Classes/Banana.h
          Classes/Banana.m
          Classes/BananaPrivate.h
        )
      end

      it 'supports an optional pattern for globbing directories' do
        paths = @path_list.relative_glob('Classes', :dir_pattern => '*.{h,m}').map(&:to_s)
        paths.sort.should == %w(
          Classes/Banana.h
          Classes/Banana.m
          Classes/BananaPrivate.h
        )
      end

      it 'handles directories specified with a trailing slash' do
        paths = @path_list.relative_glob('Classes/', :dir_pattern => '*.{h,m}').map(&:to_s)
        paths.sort.should == %w(
          Classes/Banana.h
          Classes/Banana.m
          Classes/BananaPrivate.h
        )
      end

      it 'supports an optional list of patterns to exclude' do
        exclude_patterns = ['**/*.m', '**/*Private*.*']
        paths = @path_list.relative_glob('Classes/*', :exclude_patterns => exclude_patterns).map(&:to_s)
        paths.sort.should == %w(
          Classes/Banana.h
          Classes/BananaLib.pch
          Classes/BananaTrace.d
        )
      end

      it 'allows to specify folders in the exclude patterns' do
        paths = @path_list.relative_glob('Classes/*',  :exclude_patterns => 'Classes').map(&:to_s)
        paths.sort.should.be.empty
      end

      it 'can optionally include the directories in the results' do
        paths = @path_list.relative_glob('Resources/*', :include_dirs => true).map(&:to_s)
        paths.sort.should == %w(
          Resources/Base.lproj
          Resources/Images.xcassets
          Resources/Migration.xcmappingmodel
          Resources/Sample.rcproject
          Resources/Sample.xcdatamodeld
          Resources/de.lproj
          Resources/en.lproj
          Resources/logo-sidebar.png
          Resources/sub_dir
        )
      end

      it 'can glob for exact matches' do
        paths = @path_list.relative_glob('libBananaStaticLib.a').map(&:to_s)
        paths.sort.should == %w(
          libBananaStaticLib.a
        )
      end

      it 'preserves pattern order' do
        patterns = %w(
          Classes/BananaPrivate.h
          Classes/Banana.h
          Classes/Banana.m
        )

        paths = @path_list.relative_glob(patterns).map(&:to_s)
        paths.should == %w(
          Classes/BananaPrivate.h
          Classes/Banana.h
          Classes/Banana.m
        )
      end
    end

    describe 'Reading file system' do
      it 'orders paths case insensitively' do
        root = fixture('banana-unordered')

        # Let Find.find result be ordered case-sensitively
        Find.stubs(:find).multiple_yields(
          "#{root}/Classes",
          "#{root}/Classes/NSFetchRequest+Banana.h",
          "#{root}/Classes/NSFetchedResultsController+Banana.h",
        )

        path_list = Sandbox::PathList.new(root)
        path_list.files.should == %w(Classes/NSFetchedResultsController+Banana.h Classes/NSFetchRequest+Banana.h)
      end

      it 'supports unicode paths' do
        # Load fixture("ü") with chars ["u", "̈"] instead of ["ü"]
        unicode_name = [117, 776].pack('U*')
        path_list = Sandbox::PathList.new(fixture(unicode_name))
        path_list.files.should == ['README']
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Private Helpers' do
      describe '#directory?' do
        it 'detects a directory' do
          @path_list.send(:directory?, 'classes').should == true
        end

        it "doesn't reports as a directory a file" do
          @path_list.send(:directory?, 'Classes/Banana.m').should == false
        end
      end

      #--------------------------------------#

      describe '#directory?' do
        it 'expands a pattern into all the combinations of Dir#glob literals' do
          patterns = @path_list.send(:dir_glob_equivalent_patterns, '{file1,file2}.{h,m}')
          patterns.sort.should == %w( file1.h file1.m file2.h file2.m          )
        end

        it 'returns the original pattern if there are no Dir#glob expansions' do
          patterns = @path_list.send(:dir_glob_equivalent_patterns, 'file*.*')
          patterns.sort.should == %w( file*.*          )
        end

        it 'expands `**`' do
          patterns = @path_list.send(:dir_glob_equivalent_patterns, 'Classes/**/file.m')
          patterns.sort.should == %w( Classes/**/file.m Classes/file.m          )
        end

        it 'supports a combination of `**` and literals' do
          patterns = @path_list.send(:dir_glob_equivalent_patterns, 'Classes/**/file.{h,m}')
          patterns.sort.should == %w(
            Classes/**/file.h
            Classes/**/file.m
            Classes/file.h
            Classes/file.m
          )
        end
      end

      #--------------------------------------#
    end

    #-------------------------------------------------------------------------#

    describe 'Symlinks' do
      before do
        @symlink_dir = @path_list.root + 'Classes' + 'symlinked'
        @symlink_dir_file = @symlink_dir + 'someheader.h'
        @symlink_file = @path_list.root + 'Classes' + 'symlinked.h'
        @tmpdir = Pathname.new(Dir.mktmpdir)
        tmpfile = Tempfile.new(['base', '.h'])
        @tmpfile = tmpfile.path
        tmpfile.close
        @tmpdirheader = @tmpdir + 'someheader.h'
        File.write(@tmpdirheader.to_s, '// this file does nothing. \n')
        File.write(@tmpfile.to_s, '// this file also does nothing. \n')
        FileUtils.remove_entry(@symlink_dir) if File.symlink?(@symlink_dir)
        FileUtils.remove_entry(@symlink_file) if File.symlink?(@symlink_file)
      end

      after do
        FileUtils.remove_entry(@tmpdir) if Dir.exist?(@tmpdir)
        FileUtils.remove_entry(@tmpfile) if File.exist?(@tmpfile)
        FileUtils.remove_entry(@symlink_dir) if File.symlink?(@symlink_dir)
        FileUtils.remove_entry(@symlink_file) if File.symlink?(@symlink_file)
      end

      it 'includes symlinked file' do
        @path_list.instance_variable_set(:@files, nil)
        File.symlink(@tmpfile, @symlink_file)

        @path_list.files.map(&:to_s).should.include?('Classes/symlinked.h')
      end

      it 'includes symlinked file with a different basename' do
        orange_h = @path_list.root.join('Classes', 'Orange.h')
        File.symlink('Banana.h', orange_h)

        begin
          @path_list.glob('Classes/Orange.h').should == [
            orange_h,
          ]
        ensure
          FileUtils.remove_entry(orange_h)
        end
      end

      it 'includes symlinked dir' do
        @path_list.instance_variable_set(:@dirs, nil)
        File.symlink(@tmpdir, @symlink_dir)

        @path_list.dirs.map(&:to_s).should.include?('Classes/symlinked')
      end

      it 'doesn\'t include file in symlinked dir' do
        @path_list.instance_variable_set(:@files, nil)
        @path_list.instance_variable_set(:@dirs, nil)
        File.symlink(@tmpdir, @symlink_dir)

        @path_list.files.map(&:to_s).should.not.include?('Classes/symlinked/someheader.h')
      end
    end

    #-------------------------------------------------------------------------#
  end
end
