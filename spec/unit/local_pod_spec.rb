require File.expand_path('../../spec_helper', __FILE__)

describe Pod::LocalPod do

  # a LocalPod represents a local copy of the dependency, inside the pod root, built from a spec
  describe "in general" do
    before do
      @sandbox = temporary_sandbox
      @spec    = fixture_spec('banana-lib/BananaLib.podspec')
      @pod     = Pod::LocalPod.new(@spec, @sandbox, Pod::Platform.new(:ios))
      copy_fixture_to_pod('banana-lib', @pod)
    end

    it "returns the Pod root directory path" do
      @pod.root.should == @sandbox.root + 'BananaLib'
    end

    it "creates it's own root directory if it doesn't exist" do
      @pod.create
      File.directory?(@pod.root).should.be.true
    end

    it "can execute a block within the context of it's root" do
      @pod.chdir { FileUtils.touch("foo") }
      Pathname(@pod.root + "foo").should.exist
    end

    it "can delete itself" do
      @pod.create
      @pod.implode
      @pod.root.should.not.exist
    end

    it "returns an expanded list of source files, relative to the sandbox root" do
      @pod.relative_source_files.sort.should == [
        Pathname.new("BananaLib/Classes/Banana.m"),
        Pathname.new("BananaLib/Classes/Banana.h")
      ].sort
    end

    it "returns the source files groupped by specification" do
      files = @pod.source_files_by_spec[@pod.specifications.first].sort
      files.should == [
        @pod.root + "Classes/Banana.m",
        @pod.root + "Classes/Banana.h"
      ].sort
    end

    it "returns a list of header files" do
      @pod.relative_header_files.should == [Pathname.new("BananaLib/Classes/Banana.h")]
    end

    it "returns a list of header files by specification" do
      files = @pod.header_files_by_spec[@pod.specifications.first].sort
      files.should == [ @pod.root + "Classes/Banana.h" ]
    end

    it "returns an expanded list the files to clean" do
      clean_paths = @pod.clean_paths.map { |p| p.to_s.gsub(/.*Pods\/BananaLib/,'') }
      clean_paths.should.include "/.git/config"
      # * There are some hidden files on Travis
      # * The submodule of the repo (libPusher) can be ignore, to reduce noise of this test
      clean_files_without_hidden = clean_paths.reject { |p| p.to_s.include?('/.') || p.to_s.include?('libPusher') }
      clean_files_without_hidden.should == %W[ /sub-dir /sub-dir/sub-dir-2 /sub-dir/sub-dir-2/somefile.txt ]
    end

    it "returns an expanded list of resources, relative to the sandbox root" do
      @pod.relative_resource_files.should == [Pathname.new("BananaLib/Resources/logo-sidebar.png")]
    end

    it "can link it's headers into the sandbox" do
      @pod.link_headers
      expected_header_path = @sandbox.build_headers.root + "BananaLib/Banana.h"
      expected_header_path.should.be.symlink
      File.read(expected_header_path).should == (@sandbox.root + @pod.header_files[0]).read
    end

    it "can link it's public headers into the sandbox" do
      @pod.link_headers
      expected_header_path = @sandbox.public_headers.root + "BananaLib/Banana.h"
      expected_header_path.should.be.symlink
      File.read(expected_header_path).should == (@sandbox.root + @pod.header_files[0]).read
    end

    it "can add it's source files to an Xcode project target" do
      @pod.source_file_descriptions.should == [
        Xcodeproj::Project::PBXNativeTarget::SourceFileDescription.new(Pathname.new("BananaLib/Classes/Banana.h"), "", nil),
        Xcodeproj::Project::PBXNativeTarget::SourceFileDescription.new(Pathname.new("BananaLib/Classes/Banana.m"), "", nil)
      ]
    end

    it "can add it's source files to a target with any specially configured compiler flags" do
      @pod.top_specification.compiler_flags = '-d some_flag'
      @pod.source_file_descriptions.should == [
        Xcodeproj::Project::PBXNativeTarget::SourceFileDescription.new(Pathname.new("BananaLib/Classes/Banana.h"), '-d some_flag', nil),
        Xcodeproj::Project::PBXNativeTarget::SourceFileDescription.new(Pathname.new("BananaLib/Classes/Banana.m"), '-d some_flag', nil)
      ]
    end

    it "returns the platform" do
      @pod.platform.should == :ios
    end

    it "raises if the files are accessed before creating the pod dir" do
      @pod.implode
      lambda { @pod.source_files }.should.raise Pod::Informative
    end
  end

  describe "with installed source and multiple subspecs" do

    def assert_array_equals(expected, computed)
      delta1 = computed - expected
      delta1.should == []
      delta2 = expected - computed
      delta2.should == []
    end

    before do
      @sandbox = temporary_sandbox
      subspecs = fixture_spec('chameleon/Chameleon.podspec').subspecs
      @pod = Pod::LocalPod.new(subspecs[0], @sandbox, Pod::Platform.new(:osx))
      @pod.add_specification(subspecs[1])
      copy_fixture_to_pod('chameleon', @pod)
    end

    it "identifies the top level specification" do
      @pod.top_specification.name.should == 'Chameleon'
    end

    it "returns the subspecs" do
      @pod.specifications.map(&:name).should == %w[ Chameleon/UIKit Chameleon/StoreKit ]
    end

    it "resolve the source files" do
      computed = @pod.relative_source_files.map(&:to_s)
      expected = %w[
        Chameleon/UIKit/Classes/UIKit.h
        Chameleon/UIKit/Classes/UIView.h
        Chameleon/UIKit/Classes/UIWindow.h
        Chameleon/UIKit/Classes/UIView.m
        Chameleon/UIKit/Classes/UIWindow.m
        Chameleon/StoreKit/Classes/SKPayment.h
        Chameleon/StoreKit/Classes/StoreKit.h
        Chameleon/StoreKit/Classes/SKPayment.m ]

     assert_array_equals(expected, computed)
    end

    it "resolve the resources" do
      @pod.relative_resource_files.map(&:to_s).sort.should == [
        "Chameleon/UIKit/Resources/<UITabBar> background.png",
        "Chameleon/UIKit/Resources/<UITabBar> background@2x.png" ]
    end

   it "resolve the clean paths" do
     # fake_git serves to check that source control files are deleted
     expected = %w[
       /.fake_git
       /.fake_git/branches
       /.fake_git/HEAD
       /.fake_git/index
       /AddressBookUI
       /AddressBookUI/AddressBookUI_Prefix.pch
       /AddressBookUI/Classes
       /AddressBookUI/Classes/ABUnknownPersonViewController.h
       /AddressBookUI/Classes/ABUnknownPersonViewController.m
       /AddressBookUI/Classes/AddressBookUI.h
       /AssetsLibrary
       /AssetsLibrary/AssetsLibrary_Prefix.pch
       /AssetsLibrary/Classes
       /AssetsLibrary/Classes/ALAsset.h
       /AssetsLibrary/Classes/ALAsset.m
       /AssetsLibrary/Classes/ALAssetRepresentation.h
       /AssetsLibrary/Classes/ALAssetRepresentation.m
       /AssetsLibrary/Classes/ALAssetsFilter.h
       /AssetsLibrary/Classes/ALAssetsFilter.m
       /AssetsLibrary/Classes/ALAssetsGroup.h
       /AssetsLibrary/Classes/ALAssetsGroup.m
       /AssetsLibrary/Classes/ALAssetsLibrary.h
       /AssetsLibrary/Classes/ALAssetsLibrary.m
       /AssetsLibrary/Classes/AssetsLibrary.h
       /AVFoundation
       /AVFoundation/AVFoundation_Prefix.pch
       /AVFoundation/Classes
       /AVFoundation/Classes/AVAudioPlayer.h
       /AVFoundation/Classes/AVAudioPlayer.m
       /AVFoundation/Classes/AVAudioSession.h
       /AVFoundation/Classes/AVAudioSession.m
       /AVFoundation/Classes/AVFoundation.h
       /MediaPlayer
       /MediaPlayer/Classes
       /MediaPlayer/Classes/MediaPlayer.h
       /MediaPlayer/Classes/MPMediaPlayback.h
       /MediaPlayer/Classes/MPMoviePlayerController.h
       /MediaPlayer/Classes/MPMoviePlayerController.m
       /MediaPlayer/Classes/MPMusicPlayerController.h
       /MediaPlayer/Classes/MPMusicPlayerController.m
       /MediaPlayer/Classes/UIInternalMovieView.h
       /MediaPlayer/Classes/UIInternalMovieView.m
       /MediaPlayer/MediaPlayer_Prefix.pch
       /MessageUI
       /MessageUI/Classes
       /MessageUI/Classes/MessageUI.h
       /MessageUI/Classes/MFMailComposeViewController.h
       /MessageUI/Classes/MFMailComposeViewController.m
       /MessageUI/MessageUI_Prefix.pch
       /StoreKit/StoreKit_Prefix.pch
       /UIKit/UIKit_Prefix.pch
     ]
     computed = @pod.clean_paths.each{ |p| p.gsub!(@pod.root.to_s, '') }
     assert_array_equals(expected, computed)
    end

    it "resolves the used files" do
      expected = %w[
        /UIKit/Classes/UIKit.h
        /UIKit/Classes/UIView.h
        /UIKit/Classes/UIWindow.h
        /UIKit/Classes/UIView.m
        /UIKit/Classes/UIWindow.m
        /StoreKit/Classes/SKPayment.h
        /StoreKit/Classes/StoreKit.h
        /StoreKit/Classes/SKPayment.m
        /Chameleon.podspec
        /README.md
        /LICENSE
      ] + [
        "/UIKit/Resources/<UITabBar> background.png",
        "/UIKit/Resources/<UITabBar> background@2x.png"
      ]
      computed = @pod.used_files.map{ |p| p.gsub!(@pod.root.to_s, '').to_s }
      assert_array_equals(expected, computed)
    end

    it "resolved the header files" do
      expected = %w[
        Chameleon/UIKit/Classes/UIKit.h
        Chameleon/UIKit/Classes/UIView.h
        Chameleon/UIKit/Classes/UIWindow.h
        Chameleon/StoreKit/Classes/SKPayment.h
        Chameleon/StoreKit/Classes/StoreKit.h ]
      computed = @pod.relative_header_files.map(&:to_s)
      assert_array_equals(expected, computed)
    end

    it "resolves the documentation header files including not activated subspecs" do
      subspecs = fixture_spec('chameleon/Chameleon.podspec').subspecs
      spec = subspecs[0]
      spec.stubs(:public_header_files).returns("UIKit/Classes/*Kit.h")
      @pod = Pod::LocalPod.new(spec, @sandbox, Pod::Platform.new(:osx))
      # Note we only activated UIKit but all the specs need to be resolved
      computed = @pod.documentation_headers.map { |p| p.relative_path_from(@pod.root).to_s }

      # The Following headers are private:
      # UIKit/Classes/UIView.h
      # UIKit/Classes/UIWindow.h
      expected = %w[
        UIKit/Classes/UIKit.h
        StoreKit/Classes/SKPayment.h
        StoreKit/Classes/StoreKit.h
        MessageUI/Classes/MessageUI.h
        MessageUI/Classes/MFMailComposeViewController.h
        MediaPlayer/Classes/MediaPlayer.h
        MediaPlayer/Classes/MPMediaPlayback.h
        MediaPlayer/Classes/MPMoviePlayerController.h
        MediaPlayer/Classes/MPMusicPlayerController.h
        MediaPlayer/Classes/UIInternalMovieView.h
        AVFoundation/Classes/AVAudioPlayer.h
        AVFoundation/Classes/AVAudioSession.h
        AVFoundation/Classes/AVFoundation.h
        AssetsLibrary/Classes/ALAsset.h
        AssetsLibrary/Classes/ALAssetRepresentation.h
        AssetsLibrary/Classes/ALAssetsFilter.h
        AssetsLibrary/Classes/ALAssetsGroup.h
        AssetsLibrary/Classes/ALAssetsLibrary.h
        AssetsLibrary/Classes/AssetsLibrary.h
      ]
      assert_array_equals(expected, computed)
    end

    it "merges the xcconfigs without duplicates" do
      @pod.xcconfig.should == {
        "OTHER_LDFLAGS"=>"-framework AppKit -framework Foundation -framework IOKit -framework QTKit -framework QuartzCore -framework SystemConfiguration -framework WebKit" }
    end

    it "returns a hash of mappings with a custom header dir prefix" do
      mappings = @pod.send(:header_mappings, @pod.header_files_by_spec)
      mappings = mappings.map do |folder, headers|
        "#{folder} > #{headers.sort.map{ |p| p.relative_path_from(@pod.root).to_s }.join(' ')}"
      end
      mappings.sort.should == [
        "Chameleon/StoreKit > StoreKit/Classes/SKPayment.h StoreKit/Classes/StoreKit.h",
        "Chameleon/UIKit > UIKit/Classes/UIKit.h UIKit/Classes/UIView.h UIKit/Classes/UIWindow.h" ]
    end

    it "respects the headers excluded from the search paths" do
      @pod.stubs(:headers_excluded_from_search_paths).returns([@pod.root + 'UIKit/Classes/UIKit.h'])
      mappings = @pod.send(:header_mappings, @pod.header_files_by_spec)
      mappings = mappings.map do |folder, headers|
        "#{folder} > #{headers.sort.map{ |p| p.relative_path_from(@pod.root).to_s }.join(' ')}"
      end
      mappings.sort.should == [
        "Chameleon/StoreKit > StoreKit/Classes/SKPayment.h StoreKit/Classes/StoreKit.h",
        "Chameleon/UIKit > UIKit/Classes/UIView.h UIKit/Classes/UIWindow.h" ]
    end

    # @TODO: This is done by the sandbox and this test should be moved
    it "includes the sandbox of the pod's headers while linking" do
      @sandbox.build_headers.expects(:add_search_path).with(Pathname.new('Chameleon'))
      @sandbox.public_headers.expects(:add_search_path).with(Pathname.new('Chameleon'))
      @pod.link_headers
    end

    it "differentiates among public and build headers" do
      subspecs = fixture_spec('chameleon/Chameleon.podspec').subspecs
      spec = subspecs[0]
      spec.stubs(:public_header_files).returns("UIKit/Classes/*Kit.h")
      @pod = Pod::LocalPod.new(spec, @sandbox, Pod::Platform.new(:osx))
      build_headers = @pod.header_files_by_spec.values.flatten.map{ |p| p.basename.to_s }
      public_headers = @pod.public_header_files_by_spec.values.flatten.map{ |p| p.basename.to_s }
      build_headers.sort.should == %w{ UIKit.h UIView.h UIWindow.h }
      public_headers.should == %w{ UIKit.h }
    end
  end

  describe "concerning a Pod with a local source" do
    extend SpecHelper::TemporaryDirectory

    before do
      @local_path = temporary_directory + 'localBanana'
      @sandbox = temporary_sandbox
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      @spec.source = {:local => @local_path}
      @pod = Pod::LocalPod::LocalSourcedPod.new(@spec, @sandbox, Pod::Platform.new(:ios))
    end

    it "is marked as local" do
      @pod.to_s.should.include? '[LOCAL]'
    end

    it "is marked as downloaded" do
      @pod.downloaded?.should.be.true
    end

    it "correctly repports the root of the pod" do
      @pod.root.should == @local_path
    end

    it "doesn't create the root" do
      @pod.create
      @local_path.exist?.should.be.false
    end

    before do
      FileUtils.cp_r(fixture('banana-lib'), @local_path)
    end

    it "doesn't cleans the user files" do
      useless_file = @local_path + 'useless.txt'
      FileUtils.touch(useless_file)
      @pod.root.should == @local_path
      @pod.clean!
      useless_file.exist?.should.be.true
    end

    it "doesn't implode" do
      @pod.implode
      @local_path.exist?.should.be.true
    end

    it "detects the files of the pod" do
      @pod.source_files.map {|path| path.to_s.gsub(/.*tmp\//,'') }.sort.should == [
        "localBanana/Classes/Banana.m",
        "localBanana/Classes/Banana.h"
      ].sort
    end
  end
end
