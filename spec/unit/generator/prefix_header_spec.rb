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

    it "does not duplicate the contents of the specification's prefix header when a subspec is declared" do
      @spec.prefix_header_contents = '#import "BlocksKit.h"'
      @spec.prefix_header_file = nil
      # Declaring a subspec was found in issue #1449 to generate duplicates of the prefix_header_contents
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

    it "does not duplicate the contents of the specification's prefix header when a subspec is declared multiple times" do
      @spec.prefix_header_contents = '#import "BlocksKit.h"'
      @spec.prefix_header_file = nil
      # Declaring a subspec was found in issue #1449 to generate duplicates of the prefix_header_contents
      @spec.subspec 'UI' do |su|
          su.source_files = 'Source/UI/*.{h,m}'
      end
    
      @spec.subspec 'Helpers' do |sh|
          sh.source_files = 'Source/Helpers/*.{h,m}'
      end
    
      @spec.subspec 'Additions' do |sa|
          sa.source_files = 'Source/Additions/*.{h,m}'
      end
    
      @spec.subspec 'Dashboard' do |sd|
          sd.source_files = 'Source/Dashboard/*.{h,m}'
          sd.resources    = 'Source/Dashboard/*.{xib}'
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
