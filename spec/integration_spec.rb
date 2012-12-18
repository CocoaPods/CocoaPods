require File.expand_path('../spec_helper', __FILE__)
require 'yaml'

# TODO Make specs faster by limiting remote network connections

#-----------------------------------------------------------------------------#

# @!group Helpers

def skip_xcodebuild?
  ENV['SKIP_XCODEBUILD']
end

puts " [!] ".red << "Skipping xcodebuild based checks, because it can't be found." if skip_xcodebuild?

def should_xcodebuild(target_definition)
  return if skip_xcodebuild?
  target = target_definition
  Dir.chdir(config.project_pods_root) do
    print "[!] Compiling #{target.label}...\r"
    should_successfully_perform "xcodebuild -target '#{target.label}'"
    product_name = "lib#{target_definition.label}.a"
    lib_path = config.project_pods_root + "build/Release#{'-iphoneos' if target.platform == :ios}" + product_name
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
      # fixture('spec-repos/master') # ensure the archive is unpacked
      config.integrate_targets = false
    end

    #-------------------------------------------------------------------------#

    describe "Single platform" do

      # it "includes automatically inherited subspecs" do
      # end

      # it "handles different subspecs for the same Pod in different target definitions" do
      # end

      it "installs a Pod directly from its repo" do
        url = fixture('integration/sstoolkit').to_s
        commit = '2adcd0f81740d6b0cd4589af98790eee3bd1ae7b'
        podfile = Podfile.new do
          platform :ios
          xcodeproj 'dummy'
          pod 'SSToolkit', :git => url, :commit => commit
        end

        installer = Installer.new(config.sandbox, podfile)
        installer.install!
        lockfile = installer.lockfile.to_hash
        lockfile['PODS'].should  == ['SSToolkit (0.1.3)']
        lockfile['DEPENDENCIES'].should == ["SSToolkit (from `#{url}`, commit `#{commit}`)"]
        lockfile['EXTERNAL SOURCES'].should == {"SSToolkit" => { :git=>url, :commit=>commit}}
      end

      #--------------------------------------#

      # @todo Using the podspec from the repo might invalidate the test.
      #
      it "installs a library with a podspec outside of the repo" do
        url = fixture('integration/Reachability/Reachability.podspec').to_s
        podfile = Podfile.new do
          platform :ios
          xcodeproj 'dummy'
          pod 'Reachability', :podspec => url
        end

        installer = Installer.new(config.sandbox, podfile)
        installer.install!
        lockfile = installer.lockfile.to_hash
        lockfile['PODS'].should  == ['Reachability (3.0.0)']
        lockfile['DEPENDENCIES'].should == ["Reachability (from `#{url}`)"]
        lockfile['EXTERNAL SOURCES'].should == {"Reachability"=>{ :podspec=> url}}
      end

      #--------------------------------------#

      it "installs a dummy source file" do
        podfile = Podfile.new do
          platform :ios
          pod 'JSONKit'
        end

        installer = Installer.new(config.sandbox, podfile)
        installer.install!

        dummy = (config.project_pods_root + 'PodsDummy_Pods.m').read
        dummy.should.include?('@implementation PodsDummy_Pods')
      end

      #--------------------------------------#

      it "installs a dummy source file unique to the target" do
        podfile = Podfile.new do
          platform  :ios
          xcodeproj 'dummy'
          pod 'JSONKit'
          target :AnotherTarget do
            pod 'ASIHTTPRequest'
          end
        end

        installer = Installer.new(config.sandbox, podfile)
        installer.install!

        dummy = (config.project_pods_root + 'PodsDummy_Pods_AnotherTarget.m').read
        dummy.should.include?('@implementation PodsDummy_Pods_AnotherTarget')
      end

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
            [ "ASIHTTPRequest/ASIWebPageRequest (= 1.8.1)",
              "ASIHTTPRequest/CloudFiles (= 1.8.1)",
              "ASIHTTPRequest/S3 (= 1.8.1)",
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

      if `which appledoc`.strip.empty?
        puts "    ! ".red << "Skipping documentation generation specs, because appledoc can't be found."
      else
        it "generates documentation of all pods by default" do

          podfile = Podfile.new do
            platform :ios
            xcodeproj 'dummy'
            pod 'JSONKit', '1.4'
            pod 'SSToolkit', '1.0.0'
          end

          config.generate_docs = true
          config.doc_install   = false
          Generator::Documentation.any_instance.stubs(:already_installed?).returns(false)
          installer = Installer.new(config.sandbox, podfile)
          installer.install!

          doc = (config.project_pods_root + 'Documentation/JSONKit/html/index.html').read
          doc.should.include?('<title>JSONKit 1.4 Reference</title>')
          doc = (config.project_pods_root + 'Documentation/SSToolkit/html/index.html').read
          doc.should.include?('<title>SSToolkit 1.0.0 Reference</title>')
        end
      end
    end

    #-------------------------------------------------------------------------#

    [:ios, :osx].each do |test_platform|

      describe "Multi-platform (#{test_platform})" do

        before do
          FileUtils.cp_r(fixture('integration/.'), config.project_pods_root)
        end

        #--------------------------------------#

        it "runs the optional pre-install callback defined in the Podfile *before* the targets are integrated but *after* the pods have been downloaded" do
          podfile = Podfile.new do
            platform test_platform
            xcodeproj 'dummy'
            pod 'SSZipArchive', '0.1.0'

            pre_install do |installer|
              memo = "PODS:#{installer.pods * ', '} TARGETS:#{installer.project.targets.to_a * ', '}"
              File.open(installer.config.project_pods_root + 'memo.txt', 'w') {|f| f.puts memo}
            end
          end

          Installer.new(config.sandbox, podfile).install!
          File.open(config.project_pods_root + 'memo.txt','rb').read.should == "PODS:SSZipArchive (0.1.0) TARGETS:\n"
        end

        #--------------------------------------#

        it "runs the optional post-install callback defined in the Podfile *before* the project is saved to disk" do
          podfile = Podfile.new do
            platform test_platform
            xcodeproj 'dummy'
            pod 'SSZipArchive', '0.1.0'

            post_install do |installer|
              target = installer.project.targets.first
              target.build_configurations.each do |config|
                config.build_settings['GCC_ENABLE_OBJC_GC'] = 'supported'
              end
            end
          end


          Installer.new(config.sandbox, podfile).install!
          project = Project.new(config.project_pods_root + 'Pods.xcodeproj')
          project.targets.first.build_configurations.map do |config|
            config.build_settings['GCC_ENABLE_OBJC_GC']
          end.should == %w{ supported supported }
        end

        #--------------------------------------#

        # TODO add a simple source file which uses the compiled lib to check that it really really works
        it "activates required pods and create a working static library xcode project" do
          podfile = Podfile.new do
            platform test_platform
            xcodeproj 'dummy'
            if test_platform == :ios
              pod 'Reachability',      '> 2.0.5'
            end
            pod 'JSONKit',           '>= 1.0'
            pod 'SSZipArchive',      '< 0.1.2'
          end


          installer = Installer.new(config.sandbox, podfile)
          installer.install!

          lockfile_contents = {
            'PODS' => [
              'JSONKit (999.999.999)',
              'Reachability (3.1.0)',
              'SSZipArchive (0.1.1)',
            ],
            'DEPENDENCIES' => [
              "JSONKit (>= 1.0)",
              "Reachability (> 2.0.5)",
              "SSZipArchive (< 0.1.2)",
            ],
            "COCOAPODS" => VERSION
          }

          unless test_platform == :ios
            # No Reachability is required by ASIHTTPRequest on OSX
            lockfile_contents['DEPENDENCIES'].delete_at(1)
            lockfile_contents['PODS'].delete_at(1)
            # lockfile_contents['PODS'][0] = 'ASIHTTPRequest (1.8.1)'
          end
          lockfile = installer.lockfile.to_hash
          lockfile.delete("SPEC CHECKSUMS")
          lockfile.should == lockfile_contents

          root = config.project_pods_root
          (root + 'Pods.xcconfig').read.should == installer.libraries.first.xcconfig.to_s
          project_file = (root + 'Pods.xcodeproj/project.pbxproj').to_s
          Xcodeproj.read_plist(project_file).should == installer.project.to_hash

          should_xcodebuild(podfile.target_definitions[:default])
        end

        #--------------------------------------#

        it "adds resources to the xcode copy script" do
          podfile = Podfile.new do
            platform test_platform
            xcodeproj 'dummy'
            pod 'SSZipArchive', '0.1.0'
          end

          installer = Installer.new(config.sandbox, podfile)
          installer.install!
          resources_value = { :resources => ['LICEN*', 'Readme.*'] }
          resources_pattern = { :ios => resources_value, :osx => resources_value}
          Specification.any_instance.stubs(:resources).returns(resources_pattern)

          contents = (config.project_pods_root + 'Pods-resources.sh').read
          contents.should.include "install_resource 'SSZipArchive/LICENSE'\n" \
            "install_resource 'SSZipArchive/Readme.markdown'"
        end

        #--------------------------------------#

        # @todo we need to do more cleaning and/or add a --prune task
        #
        it "overwrites an existing project.pbxproj file" do
          podfile = Podfile.new do
            platform test_platform
            xcodeproj 'dummy'
            pod 'JSONKit'
          end
          installer = Installer.new(config.sandbox, podfile)
          installer.install!

          podfile = Podfile.new do
            platform test_platform
            xcodeproj 'dummy'
            pod 'SSZipArchive', '0.1.0'
          end
          installer = Installer.new(config.sandbox, podfile)
          installer.install!

          project = Project.new(config.project_pods_root + 'Pods.xcodeproj')
          disk_source_files = project.files.sort.reject { |f| f.build_files.empty? }
          installer_source_files = installer.project.files.sort.reject { |f| f.build_files.empty? }
          disk_source_files.should == installer_source_files
        end

        #--------------------------------------#

        it "creates a project with multiple targets" do
          podfile = Podfile.new do
            platform test_platform
            pod 'ASIHTTPRequest'

            target :debug  do
              pod 'SSZipArchive', '0.1.0'
            end

            target :test, :exclusive => true do
              pod 'JSONKit'
            end
          end

          installer = Installer.new(config.sandbox, podfile)
          installer.install!

          project = Xcodeproj::Project.new(config.project_pods_root + 'Pods.xcodeproj')
          project.targets.count.should == 3
          project.targets.each do |target|
            phase = target.build_phases.find { |phase| phase.isa == 'PBXSourcesBuildPhase' }
            files = phase.files.map { |bf| bf.file_ref.name }
            case target.product_name
            when 'Pods'
              files.should.include      "ASIHTTPRequest.m"
              files.should.not.include  "SSZipArchive.m"
              files.should.not.include  "JSONKit.m"
            when 'Pods-debug'
              files.should.include      "ASIHTTPRequest.m"
              files.should.include      "SSZipArchive.m"
              files.should.not.include  "JSONKit.m"
            when 'Pods-test'
              files.should.include      "JSONKit.m"
              files.should.not.include  "ASIHTTPRequest.m"
              files.should.not.include  "SSZipArchive.m"
            end
          end

          expected_files = %w[
            Pods.xcconfig
            Pods-debug.xcconfig
            Pods-test.xcconfig
            Pods-resources.sh
            Pods-debug-resources.sh
            Pods-test-resources.sh
          ]

          expected_files.each do |file|
            (config.project_pods_root + file).should.exist
          end

          should_xcodebuild(podfile.target_definitions[:default])
          should_xcodebuild(podfile.target_definitions[:debug])
          should_xcodebuild(podfile.target_definitions[:test])
        end

        #--------------------------------------#

        # @note The shell script should be the last phase.
        #
        it "sets up an existing project with pods" do
          config.integrate_targets = true

          basename = test_platform == :ios ? 'iPhone' : 'Mac'
          projpath = temporary_directory + 'ASIHTTPRequest.xcodeproj'
          FileUtils.cp_r(fixture("integration/ASIHTTPRequest/#{basename}.xcodeproj"), projpath)

          podfile = Podfile.new do
            platform test_platform
            xcodeproj projpath
            pod 'SSZipArchive', '0.1.0'
          end

          installer = Installer.new(config.sandbox, podfile)
          installer.install!

          workspace = Xcodeproj::Workspace.new_from_xcworkspace(temporary_directory + 'ASIHTTPRequest.xcworkspace')
          workspace.projpaths.sort.should == ['ASIHTTPRequest.xcodeproj', 'Pods/Pods.xcodeproj']

          project = Project.new(projpath)
          libPods = project.files.find { |f| f.name == 'libPods.a' }

          target = project.targets.first
          target.build_configurations.each do |config|
            config.base_configuration_reference.path.should == 'Pods/Pods.xcconfig'
          end
          target.frameworks_build_phase.files.should.include libPods.build_files.first
          target.build_phases.last.shell_script.should == %{"${SRCROOT}/Pods/Pods-resources.sh"\n}
        end

        #--------------------------------------#

        it "should prevent duplication cleaning headers symlinks with multiple targets" do
          podfile = Podfile.new do
            platform test_platform
            xcodeproj 'dummy'
            target(:debug) { pod 'SSZipArchive', '0.1.0' }
            target(:test, :exclusive => true) { pod 'JSONKit' }
            pod 'ASIHTTPRequest', '1.8.1'
          end

          installer = Installer.new(config.sandbox, podfile)
          installer.install!

          root = config.project_pods_root
          (root + 'Pods.xcconfig').should.exist
          (root + 'Headers').should.exist
          (root + 'Headers/SSZipArchive').should.exist
          (root + 'Headers/ASIHTTPRequest').should.exist
          (root + 'Headers/JSONKit').should.exist
          Pathname.glob(File.join(root.to_s, 'Headers/ASIHTTPRequest/*.h')).size.should.be > 0
          Pathname.glob(File.join(root.to_s, 'Headers/SSZipArchive/*.h')).size.should.be > 0
          Pathname.glob(File.join(root.to_s, 'Headers/JSONKit/*.h')).size.should.be > 0
        end

      end
    end
  end
end
