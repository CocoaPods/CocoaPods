require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Hooks::PodRepresentation do

    before do
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @root = fixture('banana-lib')
      @file_accessor = Sandbox::FileAccessor.new(Sandbox::PathList.new(@root), @spec.consumer(:ios))
      @rep = Hooks::PodRepresentation.new('BananaLib', [@file_accessor])
    end

    #-------------------------------------------------------------------------#

    describe "Public Hooks API" do

      it "returns the name" do
        @rep.name.should == 'BananaLib'
      end

      it "returns the version" do
        @rep.version.should == Version.new('1.0')
      end


      it "returns the root specification" do
        @rep.root_spec.should == @spec
      end


      it "returns all the activated specifications" do
        @rep.specs.should == [@spec]
      end


      it "returns the directory where the pod is stored" do
        @rep.root.should == @root
      end

      it "returns the source files" do
        source_files = @rep.source_files.map{ |sf| sf.relative_path_from(@root).to_s }.sort
        source_files.should == [
          "Classes/Banana.h",
          "Classes/Banana.m",
          "Classes/BananaPrivate.h"
        ]
      end

    end

    #-------------------------------------------------------------------------#

  end
end
