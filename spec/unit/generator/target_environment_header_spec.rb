require File.expand_path('../../../spec_helper', __FILE__)

describe Pod::Generator::TargetEnvironmentHeader do

  before do
    specification = fixture_spec('banana-lib/BananaLib.podspec')
    @gen = Pod::Generator::TargetEnvironmentHeader.new({'Debug' => [specification]})
  end

  it "generates a header files which include macro definitions for installed Pods" do
    file = temporary_directory + 'Pods-environment.h'
    @gen.save_as(file)
    file.read.should == <<-EOS.strip_heredoc

      // To check if a library is compiled with CocoaPods you
      // can use the `COCOAPODS` macro definition which is
      // defined in the xcconfigs so it is available in
      // headers also when they are imported in the client
      // project.


      // BananaLib
      #define COCOAPODS_POD_AVAILABLE_BananaLib
      #define COCOAPODS_VERSION_MAJOR_BananaLib 1
      #define COCOAPODS_VERSION_MINOR_BananaLib 0
      #define COCOAPODS_VERSION_PATCH_BananaLib 0

    EOS
  end

  it "handles specifications with special characters" do
    name = @gen.send(:safe_spec_name, 'AppleCoreAudioUtilityClasses@thehtb')
    name.should == 'AppleCoreAudioUtilityClasses_thehtb'
  end
end

