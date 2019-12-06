require File.expand_path('../../../spec_helper', __FILE__)
require 'cocoapods/xcode'
require 'macho'

describe LinkageAnalyzer = Pod::Xcode::LinkageAnalyzer do
  describe '#dynamic_binary?' do
    it 'not a dynamic binary if its not a file' do
      binary = stub('binary', :file? => false)
      LinkageAnalyzer.dynamic_binary?(binary).should.be.false
    end

    it 'uses the cache after the first time' do
      binary = stub('binary', :file? => true)
      macho_file = stub('macho_file', :dylib? => true)
      MachO.stubs(:open).once.returns(macho_file)
      LinkageAnalyzer.dynamic_binary?(binary).should.be.true
      LinkageAnalyzer.dynamic_binary?(binary).should.be.true
    end
  end
end
