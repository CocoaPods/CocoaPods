require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe PrefixHeader = Generator::PrefixHeader do
    before do
      file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
      @spec = file_accessor.spec
      @gen = PrefixHeader.new([file_accessor], Platform.ios)
    end

    it "includes the contents of the specification's prefix header" do
      @spec.prefix_header_contents = '#import "BlocksKit.h"'
      @spec.prefix_header_file = nil
      @gen.generate.should == <<-EOS.strip_heredoc
      #ifdef __OBJC__
      #import <UIKit/UIKit.h>
      #endif

      #import "BlocksKit.h"
      EOS
    end

    # @note Declaring a subspec was found in issue #1449 to generate duplicates of the prefix_header_contents
    it "does not duplicate the contents of the specification's prefix header when a subspec is declared" do
      @spec.prefix_header_contents = '#import "BlocksKit.h"'
      @spec.prefix_header_file = nil
      @spec.subspec 'UI' do |subspec|
        subspec.source_files = 'Source/UI/*.{h,m}'
      end
      @gen.generate.should == <<-EOS.strip_heredoc
      #ifdef __OBJC__
      #import <UIKit/UIKit.h>
      #endif

      #import "BlocksKit.h"
      EOS
    end

    # @note Declaring a subspec was found in issue #1449 to generate duplicates of the prefix_header_contents
    it "does not duplicate the contents of the specification's prefix header when a subspec is declared multiple times" do
      @spec.prefix_header_contents = '#import "BlocksKit.h"'
      @spec.prefix_header_file = nil
      @spec.subspec 'UI' do |su|
        su.source_files = 'Source/UI/*.{h,m}'
      end

      @spec.subspec 'Helpers' do |sh|
        sh.source_files = 'Source/Helpers/*.{h,m}'
      end

      @gen.generate.should == <<-EOS.strip_heredoc
      #ifdef __OBJC__
      #import <UIKit/UIKit.h>
      #endif

      #import "BlocksKit.h"
      EOS
    end

    it "includes the contents of the specification's prefix header file" do
      @gen.generate.should == <<-EOS.strip_heredoc
      #ifdef __OBJC__
      #import <UIKit/UIKit.h>
      #endif

      #import <BananaTree/BananaTree.h>
      EOS
    end

    # @note Declaring a subspec was found in issue #3283 to generate duplicates of the prefix_header
    it "does not duplicate the contents of the specification's prefix header file when a subspec is declared multiple times" do
      @spec.subspec 'UI' do |su|
        su.source_files = 'Source/UI/*.{h,m}'
      end

      @gen.file_accessors << @gen.file_accessors.first.dup.tap do |fa|
        fa.stubs(:spec_consumer).returns Specification::Consumer.new(@spec.subspec_by_name('BananaLib/UI'), Platform.ios)
      end

      @gen.generate.should == <<-EOS.strip_heredoc
      #ifdef __OBJC__
      #import <UIKit/UIKit.h>
      #endif

      #import <BananaTree/BananaTree.h>
      EOS
    end

    it 'includes the imports' do
      @gen.imports << 'header.h'
      @gen.generate.should == <<-EOS.strip_heredoc
      #ifdef __OBJC__
      #import <UIKit/UIKit.h>
      #endif

      #import "header.h"
      #import <BananaTree/BananaTree.h>
      EOS
    end

    it 'writes the prefix header file to the disk' do
      path = temporary_directory + 'Test.pch'
      @gen.save_as(path)
      path.read.should == <<-EOS.strip_heredoc
      #ifdef __OBJC__
      #import <UIKit/UIKit.h>
      #endif

      #import <BananaTree/BananaTree.h>
      EOS
    end
  end
end
