require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Sandbox::PathList do

    before do
      @path_list = Sandbox::PathList.new(fixture('banana-lib'))
    end

    describe "In general" do

      it "creates the list of all the files" do
        files = @path_list.files
        files.reject! do |f|
          f.include?('libPusher') || f.include?('.git') || f.include?('DS_Store')
        end
        expected = %w[
          BananaLib.podspec
          Classes/Banana.h
          Classes/Banana.m
          Classes/BananaLib.pch
          Classes/BananaPrivate.h
          README
          Resources/logo-sidebar.png
          preserve_me.txt
          sub-dir/sub-dir-2/somefile.txt
        ]

        files.sort.should == expected
      end

      it "creates the list of the directories" do
        dirs = @path_list.dirs
        dirs.reject! do |f|
          f.include?('libPusher') || f.include?('.git')
        end
        dirs.sort.should == %w| Classes Resources sub-dir sub-dir/sub-dir-2 |
      end

    end

    #-------------------------------------------------------------------------#

    describe "Globbing" do


      it "can glob the root for a given pattern" do
        paths = @path_list.relative_glob('Classes/*.{h,m}').map(&:to_s)
        paths.sort.should == %w[
          Classes/Banana.h
          Classes/Banana.m
          Classes/BananaPrivate.h
        ]
      end

      it "supports the `**` glob pattern" do
        paths = @path_list.relative_glob('Classes/**/*.{h,m}').map(&:to_s)
        paths.sort.should == %w[
          Classes/Banana.h
          Classes/Banana.m
          Classes/BananaPrivate.h
        ]
      end

      it "supports an optional pattern for globbing directories" do
        paths = @path_list.relative_glob('Classes', '*.{h,m}').map(&:to_s)
        paths.sort.should == %w[
          Classes/Banana.h
          Classes/Banana.m
          Classes/BananaPrivate.h
        ]
      end

      it "supports an optional list of patterns to exclude" do
        exclude_patterns = ['**/*.m', '**/*Private*.*']
        paths = @path_list.relative_glob('Classes/*', nil, exclude_patterns).map(&:to_s)
        paths.sort.should == %w[
          Classes/Banana.h
          Classes/BananaLib.pch
        ]
      end

      it "can return the absolute paths from glob" do
        paths = @path_list.glob('Classes/*.{h,m}')
        paths.all? { |p| p.absolute? }.should == true
      end

      it "can return the relative paths from glob" do
        paths = @path_list.relative_glob('Classes/*.{h,m}')
        paths.any? { |p| p.absolute? }.should == false
      end
    end

    #-------------------------------------------------------------------------#

    describe "Private Helpers" do

      describe "#directory?" do
        it "detects a directory" do
          @path_list.send(:directory?, 'classes').should == true
        end

        it "doesn't reports as a directory a file" do
          @path_list.send(:directory?, 'Classes/Banana.m').should == false
        end
      end


      describe "#directory?" do
        it "expands a pattern into all the combinations of Dir#glob literals" do
          patterns = @path_list.send(:dir_glob_equivalent_patterns, '{file1,file2}.{h,m}')
          patterns.sort.should == %w[ file1.h file1.m file2.h file2.m ]
        end

        it "returns the original pattern if there are no Dir#glob expansions" do
          patterns = @path_list.send(:dir_glob_equivalent_patterns, 'file*.*')
          patterns.sort.should == %w[ file*.* ]
        end

        it "expands `**`" do
          patterns = @path_list.send(:dir_glob_equivalent_patterns, 'Classes/**/file.m')
          patterns.sort.should == %w[ Classes/**/file.m Classes/file.m ]
        end

        it "supports a combination of `**` and literals" do
          patterns = @path_list.send(:dir_glob_equivalent_patterns, 'Classes/**/file.{h,m}')
          patterns.sort.should == %w[
            Classes/**/file.h
            Classes/**/file.m
            Classes/file.h
            Classes/file.m
          ]
        end
      end
    end

    #-------------------------------------------------------------------------#

  end
end
