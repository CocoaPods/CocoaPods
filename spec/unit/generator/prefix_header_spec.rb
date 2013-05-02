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

    it "includes the contents of the specification's prefix header file" do
      @gen.generate.should == <<-EOS.strip_heredoc
      #ifdef __OBJC__
      #import <UIKit/UIKit.h>
      #endif

      #import <BananaTree/BananaTree.h>
      EOS
    end

    it "includes the imports" do
      @gen.imports << "header.h"
      @gen.generate.should == <<-EOS.strip_heredoc
      #ifdef __OBJC__
      #import <UIKit/UIKit.h>
      #endif

      #import "header.h"
      #import <BananaTree/BananaTree.h>
      EOS
    end

    it "imports UIKit in iOS platforms" do
      @gen.stubs(:platform).returns(Pod::Platform.ios)
      @gen.generate.should.include?('#import <UIKit/UIKit.h>')
    end

    it "imports Cocoa for OS X platforms" do
      @gen.stubs(:platform).returns(Pod::Platform.osx)
      @gen.generate.should.include?('#import <Cocoa/Cocoa.h>')
    end

    it "writes the prefix header file to the disk" do
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
