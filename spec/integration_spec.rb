require File.expand_path('../spec_helper', __FILE__)
require 'yaml'

#-----------------------------------------------------------------------------#
# TODO These checks need to be migrated to spec/integration_2.rb
#-----------------------------------------------------------------------------#

# @!group Helpers

def skip_xcodebuild?
  ENV['SKIP_XCODEBUILD']
end

puts " [!] ".red << "Skipping xcodebuild based checks, because it can't be found." if skip_xcodebuild?

def should_xcodebuild(target_definition)
  return if skip_xcodebuild?
  target = target_definition
  Dir.chdir(config.sandbox_root) do
    print "[!] Compiling #{target.label}...\r"
    should_successfully_perform "xcodebuild -target '#{target.label}'"
    product_name = "lib#{target_definition.label}.a"
    lib_path = config.sandbox_root + "build/Release#{'-iphoneos' if target.platform == :ios}" + product_name
    `lipo -info '#{lib_path}'`.should.include "#{target.platform == :ios ? 'armv7' : 'x86_64'}"
  end
end

def should_successfully_perform(command)
  output = `#{command} 2>&1`
  puts output unless $?.success?
  $?.should.be.success
end

#-----------------------------------------------------------------------------#

module Pod

  describe "Full integration" do

    before do
      config.integrate_targets = false
    end

    # xit "includes automatically inherited subspecs" do; end

    #--------------------------------------#

    # @note ASIHTTPRequest depends on Reachability in iOS.
    #
    it "creates targets for different platforms" do
      podfile = Podfile.new do
        platform :ios
        xcodeproj 'dummy'
        pod 'JSONKit', '1.4'
        target :ios_target do
          pod 'ASIHTTPRequest', '1.8.1'
        end
        target :osx_target do
          platform :osx
          pod 'ASIHTTPRequest', '1.8.1'
        end
      end

      installer = Installer.new(config.sandbox, podfile)
      installer.install!

      lockfile = installer.lockfile.to_hash
      lockfile['PODS'].should  == [
        { "ASIHTTPRequest (1.8.1)" =>
          [ "ASIHTTPRequest/ASIWebPageRequest",
            "ASIHTTPRequest/CloudFiles",
            "ASIHTTPRequest/S3",
            "Reachability"
          ]
      },
      { "ASIHTTPRequest/ASIWebPageRequest (1.8.1)" =>  ["Reachability"] },
      { "ASIHTTPRequest/CloudFiles (1.8.1)" =>         ["Reachability"] },
      { "ASIHTTPRequest/S3 (1.8.1)" =>                 ["Reachability"] },
      "JSONKit (1.4)",
      "Reachability (3.1.0)"
      ]
      lockfile['DEPENDENCIES'].should == ["ASIHTTPRequest (= 1.8.1)", "JSONKit (= 1.4)"]

      should_xcodebuild(podfile.target_definitions[:ios_target])
      should_xcodebuild(podfile.target_definitions[:osx_target])
    end

    #--------------------------------------#

  end
end
