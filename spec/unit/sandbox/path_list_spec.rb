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
          BananaLib.podspec
          Bananalib.framework/Versions/A/Headers/Bananalib.h
          Classes/Banana.h
          Classes/Banana.m
          Classes/BananaLib.pch
          Classes/BananaPrivate.h
          Classes/BananaTrace.d
          README
          Resources/Images.xcassets/Logo.imageset/Contents.json
          Resources/Images.xcassets/Logo.imageset/logo.png
          Resources/logo-sidebar.png
          Resources/sub_dir/logo-sidebar.png
          libBananalib.a
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
          Bananalib.framework
          Bananalib.framework/Headers
          Bananalib.framework/Versions
          Bananalib.framework/Versions/A
          Bananalib.framework/Versions/A/Headers
          Bananalib.framework/Versions/Current
          Classes
          Resources
          Resources/Images.xcassets
          Resources/Images.xcassets/Logo.imageset
          Resources/sub_dir
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
        paths = @path_list.relative_glob('Classes',  :dir_pattern => '*.{h,m}').map(&:to_s)
        paths.sort.should == %w(
          Classes/Banana.h
          Classes/Banana.m
          Classes/BananaPrivate.h
        )
      end

      it 'handles directories specified with a trailing slash' do
        paths = @path_list.relative_glob('Classes/',  :dir_pattern => '*.{h,m}').map(&:to_s)
        paths.sort.should == %w(
          Classes/Banana.h
          Classes/Banana.m
          Classes/BananaPrivate.h
        )
      end

      it 'supports an optional list of patterns to exclude' do
        exclude_patterns = ['**/*.m', '**/*Private*.*']
        paths = @path_list.relative_glob('Classes/*',  :exclude_patterns => exclude_patterns).map(&:to_s)
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
        paths = @path_list.relative_glob('Resources/*',  :include_dirs => true).map(&:to_s)
        paths.sort.should == %w(
          Resources/Images.xcassets
          Resources/logo-sidebar.png
          Resources/sub_dir
        )
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
          patterns.sort.should == %w(          file1.h file1.m file2.h file2.m          )
        end

        it 'returns the original pattern if there are no Dir#glob expansions' do
          patterns = @path_list.send(:dir_glob_equivalent_patterns, 'file*.*')
          patterns.sort.should == %w(          file*.*          )
        end

        it 'expands `**`' do
          patterns = @path_list.send(:dir_glob_equivalent_patterns, 'Classes/**/file.m')
          patterns.sort.should == %w(          Classes/**/file.m Classes/file.m          )
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

      describe '#escape_path_for_glob' do
        it 'escapes metacharacters' do
          escaped = @path_list.send(:escape_path_for_glob, '[]{}?**')
          escaped.to_s.should == '\[\]\{\}\?\*\*'
        end
      end

      #--------------------------------------#
    end

    #-------------------------------------------------------------------------#
  end
end
