require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Header = Generator::Header do
    before do
      @gen = Header.new(Pod::Platform.ios)
    end

    it 'includes the imports' do
      @gen.imports << 'header.h'
      @gen.generate.should == <<-EOS.strip_heredoc
      #import <Foundation/Foundation.h>

      #import "header.h"
      EOS
    end

    it 'includes the module imports' do
      @gen.module_imports << 'Module'
      @gen.generate.should == <<-EOS.strip_heredoc
      #import <Foundation/Foundation.h>


      @import Module
      EOS
    end

    it 'writes the header file to the disk' do
      path = temporary_directory + 'Test.h'
      @gen.save_as(path)
      path.read.should == <<-EOS.strip_heredoc
      #import <Foundation/Foundation.h>

      EOS
    end
  end
end
