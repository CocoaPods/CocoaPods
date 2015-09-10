require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Header = Generator::Header do
    before do
      @gen = Header.new(Pod::Platform.ios)
    end

    it 'includes the imports' do
      @gen.imports << 'header.h'
      @gen.generate.should == <<-EOS.strip_heredoc
      #import <UIKit/UIKit.h>

      #import "header.h"
      EOS
    end

    it 'includes the module imports' do
      @gen.module_imports << 'Module'
      @gen.generate.should == <<-EOS.strip_heredoc
      #import <UIKit/UIKit.h>


      @import Module
      EOS
    end

    it 'imports UIKit in iOS platforms' do
      @gen.stubs(:platform).returns(Pod::Platform.ios)
      @gen.generate.should.include?('#import <UIKit/UIKit.h>')
    end

    it 'imports Cocoa for OS X platforms' do
      @gen.stubs(:platform).returns(Pod::Platform.osx)
      @gen.generate.should.include?('#import <Cocoa/Cocoa.h>')
    end

    it 'imports Foundation for watchOS platforms' do
      @gen.stubs(:platform).returns(Pod::Platform.watchos)
      @gen.generate.should.include?('#import <Foundation/Foundation.h>')
    end

    it 'imports Foundation for tvOS platforms' do
      @gen.stubs(:platform).returns(Pod::Platform.tvos)
      @gen.generate.should.include?('#import <UIKit/UIKit.h>')
    end

    it 'writes the header file to the disk' do
      path = temporary_directory + 'Test.h'
      @gen.save_as(path)
      path.read.should == <<-EOS.strip_heredoc
      #import <UIKit/UIKit.h>

      EOS
    end
  end
end
