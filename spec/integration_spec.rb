require File.expand_path('../spec_helper', __FILE__)
require 'yaml'

# TODO Make specs faster by limiting remote network connections

module SpecHelper
  class Installer < Pod::Installer
    # Here we override the `source' of the pod specifications to point to the integration fixtures.
    def specs_by_target
      @specs_by_target ||= super.tap do |hash|
        hash.values.flatten.each do |spec|
          next if spec.subspec?
          source = spec.source
          source[:git] = SpecHelper.fixture("integration/#{spec.name}").to_s
          spec.source = source
        end
      end
    end
  end
end

unless SpecHelper.fixture('integration/ASIHTTPRequest/Classes').exist?
  puts "[!] You must run `git submodule update --init` for the integration spec to work, skipping."
else
  [:ios, :osx].each do |platform|
    describe "A full (integration spec) installation for platform `#{platform}'" do
      extend SpecHelper::TemporaryDirectory

      def create_config!
        config.repos_dir = fixture('spec-repos')
        config.project_root = temporary_directory
        config.integrate_targets = false
      end

      before do
        fixture('spec-repos/master') # ensure the archive is unpacked
        create_config!
      end

      def should_successfully_perform(command)
        output = `#{command} 2>&1`
        puts output unless $?.success?
        $?.should.be.success
      end

      puts "  ! ".red << "Skipping xcodebuild based checks, because it can't be found." if `which xcodebuild`.strip.empty?

      def should_xcodebuild(target_definition)
        return if `which xcodebuilda`.strip.empty?
        target = target_definition
        with_xcodebuild_available do
          Dir.chdir(config.project_pods_root) do
            print "[!] Compiling #{target.label}...\r"
            should_successfully_perform "xcodebuild -target '#{target.label}'"
            lib_path = config.project_pods_root + "build/Release#{'-iphoneos' if target.platform == :ios}" + target.lib_name
            `lipo -info '#{lib_path}'`.should.include "architecture: #{target.platform == :ios ? 'armv7' : 'x86_64'}"
          end
        end
      end

      # Lame way to run on one platform only
      if platform == :ios
        it "installs a Pod directly from its repo" do
          url = fixture('integration/sstoolkit').to_s
          commit = '2adcd0f81740d6b0cd4589af98790eee3bd1ae7b'
          podfile = Pod::Podfile.new do
            self.platform :ios
            xcodeproj 'dummy'
            pod 'SSToolkit', :git => url, :commit => commit
          end

          # Note that we are *not* using the stubbed SpecHelper::Installer subclass.
          resolver = Pod::Resolver.new(podfile, nil, Pod::Sandbox.new(config.project_pods_root))
          installer = Pod::Installer.new(resolver)
          installer.install!
          result = installer.lockfile.to_hash
          result['PODS'].should  == ['SSToolkit (0.1.3)']
          result['DEPENDENCIES'].should == ["SSToolkit (from `#{url}', commit `#{commit}')"]
          result['EXTERNAL SOURCES'].should == {"SSToolkit" => { :git=>url, :commit=>commit}}
        end

        it "installs a library with a podspec outside of the repo" do
          url = 'https://raw.github.com/gist/1349824/3ec6aa60c19113573fc48eac19d0fafd6a69e033/Reachability.podspec'
          podfile = Pod::Podfile.new do
            self.platform :ios
            xcodeproj 'dummy'
            # TODO use a local file instead of http?
            pod 'Reachability', :podspec => url
          end

          resolver = Pod::Resolver.new(podfile, nil, Pod::Sandbox.new(config.project_pods_root))
          installer = SpecHelper::Installer.new(resolver)
          installer.install!
          result = installer.lockfile.to_hash
          result['PODS'].should  == ['Reachability (1.2.3)']
          result['DEPENDENCIES'].should == ["Reachability (from `#{url}')"]
          result['EXTERNAL SOURCES'].should == {"Reachability"=>{ :podspec=>"https://raw.github.com/gist/1349824/3ec6aa60c19113573fc48eac19d0fafd6a69e033/Reachability.podspec"}}
        end

        it "installs a dummy source file" do
          create_config!
          podfile = Pod::Podfile.new do
            self.platform :ios
            xcodeproj 'dummy'
            pod do |s|
              s.name         = 'JSONKit'
              s.version      = '1.2'
              s.source       = { :git => SpecHelper.fixture('integration/JSONKit').to_s, :tag => 'v1.2' }
              s.source_files = 'JSONKit.*'
            end
          end

          resolver = Pod::Resolver.new(podfile, nil, Pod::Sandbox.new(config.project_pods_root))
          installer = SpecHelper::Installer.new(resolver)
          installer.install!

          dummy = (config.project_pods_root + 'PodsDummy_Pods.m').read
          dummy.should.include?('@implementation PodsDummy_Pods')
        end

        it "installs a dummy source file unique to the target" do
          create_config!
          podfile = Pod::Podfile.new do
            self.platform :ios
            xcodeproj 'dummy'
            pod do |s|
              s.name         = 'JSONKit'
              s.version      = '1.2'
              s.source       = { :git => SpecHelper.fixture('integration/JSONKit').to_s, :tag => 'v1.2' }
              s.source_files = 'JSONKit.*'
            end
            target :AnotherTarget do
              pod 'ASIHTTPRequest'
            end
          end

          resolver = Pod::Resolver.new(podfile, nil, Pod::Sandbox.new(config.project_pods_root))
          installer = SpecHelper::Installer.new(resolver)
          installer.install!

          dummy = (config.project_pods_root + 'PodsDummy_Pods_AnotherTarget.m').read
          dummy.should.include?('@implementation PodsDummy_Pods_AnotherTarget')
        end

        it "installs a library with a podspec defined inline" do
          podfile = Pod::Podfile.new do
            self.platform :ios
            xcodeproj 'dummy'
            pod do |s|
              s.name         = 'JSONKit'
              s.version      = '1.2'
              s.source       = { :git => SpecHelper.fixture('integration/JSONKit').to_s, :tag => 'v1.2' }
              s.source_files = 'JSONKit.*'
            end
            pod do |s|
              s.name         = 'SSZipArchive'
              s.version      = '0.1.0'
              s.source       = { :git => SpecHelper.fixture('integration/SSZipArchive').to_s, :tag => '0.1.0' }
              s.source_files = 'SSZipArchive.*', 'minizip/*.{h,c}'
            end
          end

          Pod::Specification.any_instance.stubs(:preserve_paths).returns(['CHANGELOG.md'])
          resolver = Pod::Resolver.new(podfile, nil, Pod::Sandbox.new(config.project_pods_root))
          installer = SpecHelper::Installer.new(resolver)
          installer.install!

          installer.lockfile.to_hash.tap {|d| d.delete("COCOAPODS") }.should == {
            'PODS' => ['JSONKit (1.2)', 'SSZipArchive (0.1.0)'],
            'DEPENDENCIES' => ["JSONKit (defined in Podfile)", "SSZipArchive (defined in Podfile)"]
          }

          change_log = (config.project_pods_root + 'JSONKit/CHANGELOG.md').read
          change_log.should.include '1.2'
          change_log.should.not.include '1.3'
        end

        it "creates targets for different platforms" do
          podfile = Pod::Podfile.new do
            self.platform :ios
            xcodeproj 'dummy'
            pod 'JSONKit', '1.4'
            target :ios_target do
              # This brings in Reachability on iOS
              pod 'ASIHTTPRequest'
            end
            target :osx_target do
              self.platform :osx
              pod 'ASIHTTPRequest'
            end
          end

          resolver = Pod::Resolver.new(podfile, nil, Pod::Sandbox.new(config.project_pods_root))
          installer = SpecHelper::Installer.new(resolver)
          installer.install!

          result = installer.lockfile.to_hash
          result['PODS'].should  == [
            { "ASIHTTPRequest (1.8.1)" =>                   ["ASIHTTPRequest/ASIWebPageRequest (= 1.8.1)",
                                                             "ASIHTTPRequest/CloudFiles (= 1.8.1)",
                                                             "ASIHTTPRequest/S3 (= 1.8.1)",
                                                             "Reachability"]},
           { "ASIHTTPRequest/ASIWebPageRequest (1.8.1)" =>  ["Reachability"] },
           { "ASIHTTPRequest/CloudFiles (1.8.1)" =>         ["Reachability"] },
           { "ASIHTTPRequest/S3 (1.8.1)" =>                 ["Reachability"] },
           "JSONKit (1.4)",
           "Reachability (3.0.0)"]
          result['DEPENDENCIES'].should == ["ASIHTTPRequest", "JSONKit (= 1.4)"]
          # TODO might be nicer looking to not show the dependencies of the top level spec for each subspec (Reachability).

          should_xcodebuild(podfile.target_definitions[:ios_target])
          should_xcodebuild(podfile.target_definitions[:osx_target])
        end

        unless `which appledoc`.strip.empty?
          it "generates documentation of all pods by default" do
            ::Pod::Config.instance = nil
            ::Pod::Config.instance.tap do |c|
              ENV['VERBOSE_SPECS'] ? c.verbose = true : c.silent = true
              c.doc_install   = false
              c.repos_dir = fixture('spec-repos')
              c.project_root = temporary_directory
              c.integrate_targets = false
            end

            Pod::Generator::Documentation.any_instance.stubs(:already_installed?).returns(false)

            podfile = Pod::Podfile.new do
              self.platform :ios
              xcodeproj 'dummy'
              pod 'JSONKit', '1.4'
              pod 'SSToolkit', '1.0.0'
            end
            resolver = Pod::Resolver.new(podfile, nil, Pod::Sandbox.new(config.project_pods_root))
            installer = SpecHelper::Installer.new(resolver)
            installer.install!

            doc = (config.project_pods_root + 'Documentation/JSONKit/html/index.html').read
            doc.should.include?('<title>JSONKit 1.4 Reference</title>')
            doc = (config.project_pods_root + 'Documentation/SSToolkit/html/index.html').read
            doc.should.include?('<title>SSToolkit 1.0.0 Reference</title>')
          end
        else
          puts "  ! ".red << "Skipping documentation generation specs, because appledoc can't be found."
        end
      end

      before do
        FileUtils.cp_r(fixture('integration/.'), config.project_pods_root)
      end

      it "runs the optional post_install callback defined in the Podfile _before_ the project is saved to disk" do
        podfile = Pod::Podfile.new do
          self.platform platform
          xcodeproj 'dummy'
          pod 'SSZipArchive', '0.1.0'

          post_install do |installer|
            target = installer.project.targets.first
            target.build_configurations.each do |config|
              config.build_settings['GCC_ENABLE_OBJC_GC'] = 'supported'
            end
          end
        end

        resolver = Pod::Resolver.new(podfile, nil, Pod::Sandbox.new(config.project_pods_root))
        SpecHelper::Installer.new(resolver).install!
        project = Pod::Project.new(config.project_pods_root + 'Pods.xcodeproj')
        project.targets.first.build_configurations.map do |config|
          config.build_settings['GCC_ENABLE_OBJC_GC']
        end.should == %w{ supported supported }
      end

      # TODO add a simple source file which uses the compiled lib to check that it really really works
      it "activates required pods and create a working static library xcode project" do
        podfile = Pod::Podfile.new do
          self.platform platform
          xcodeproj 'dummy'
          pod 'Reachability',      '> 2.0.5' if platform == :ios
          pod 'JSONKit',           '>= 1.0'
          pod 'SSZipArchive',      '< 0.1.2'
        end

        resolver = Pod::Resolver.new(podfile, nil, Pod::Sandbox.new(config.project_pods_root))
        installer = SpecHelper::Installer.new(resolver)
        installer.install!

        lockfile_contents = {
          'PODS' => [
            'JSONKit (1.5pre)',
            'Reachability (3.0.0)',
            'SSZipArchive (0.1.1)',
          ],
          'DEPENDENCIES' => [
            "JSONKit (>= 1.0)",
            "Reachability (> 2.0.5)",
            "SSZipArchive (< 0.1.2)",
          ],
          "COCOAPODS" => Pod::VERSION
        }
        unless platform == :ios
          # No Reachability is required by ASIHTTPRequest on OSX
          lockfile_contents['DEPENDENCIES'].delete_at(1)
          lockfile_contents['PODS'].delete_at(1)
          # lockfile_contents['PODS'][0] = 'ASIHTTPRequest (1.8.1)'
        end
        result = installer.lockfile.to_hash
        result.delete("SPECS CHECKSUM")
        result.should == lockfile_contents

        root = config.project_pods_root
        (root + 'Pods.xcconfig').read.should == installer.target_installers.first.xcconfig.to_s
        project_file = (root + 'Pods.xcodeproj/project.pbxproj').to_s
        Xcodeproj.read_plist(project_file).should == installer.project.to_hash

        should_xcodebuild(podfile.target_definitions[:default])
      end

      if platform == :ios
        it "does not activate pods that are only part of other pods" do
          spec = Pod::Podfile.new do
            self.platform platform
            xcodeproj 'dummy'
            pod 'Reachability', '2.0.4' # only 2.0.4 is part of ASIHTTPRequest’s source.
          end

          resolver = Pod::Resolver.new(spec, nil, Pod::Sandbox.new(config.project_pods_root))
          installer = SpecHelper::Installer.new(resolver)
          installer.install!

          result = installer.lockfile.to_hash
          result['PODS'].should == [ 'Reachability (2.0.4)' ]
          result['DEPENDENCIES'].should == ["Reachability (= 2.0.4)"]
        end
      end

      it "adds resources to the xcode copy script" do
        spec = Pod::Podfile.new do
          self.platform platform
          xcodeproj 'dummy'
          pod 'SSZipArchive', '0.1.0'
        end

        resolver = Pod::Resolver.new(spec, nil, Pod::Sandbox.new(config.project_pods_root))
        installer = SpecHelper::Installer.new(resolver)
        target_definition = installer.target_installers.first.target_definition
        installer.specs_by_target[target_definition].first.resources = 'LICEN*', 'Readme.*'
        installer.install!

        contents = (config.project_pods_root + 'Pods-resources.sh').read
        contents.should.include "install_resource 'SSZipArchive/LICENSE'\n" \
                                "install_resource 'SSZipArchive/Readme.markdown'"
      end

      # TODO we need to do more cleaning and/or add a --prune task
      it "overwrites an existing project.pbxproj file" do
        spec = Pod::Podfile.new do
          self.platform platform
          xcodeproj 'dummy'
          pod 'JSONKit'
        end
        resolver = Pod::Resolver.new(spec, nil, Pod::Sandbox.new(config.project_pods_root))
        installer = SpecHelper::Installer.new(resolver)
        installer.install!

        spec = Pod::Podfile.new do
          self.platform platform
          xcodeproj 'dummy'
          pod 'SSZipArchive', '0.1.0'
        end
        resolver = Pod::Resolver.new(spec, nil, Pod::Sandbox.new(config.project_pods_root))
        installer = SpecHelper::Installer.new(resolver)
        installer.install!

        project = Pod::Project.new(config.project_pods_root + 'Pods.xcodeproj')
        project.source_files.should == installer.project.source_files
      end

      it "creates a project with multiple targets" do
        podfile = Pod::Podfile.new do
          self.platform platform
          xcodeproj 'dummy'
          target(:debug) { pod 'SSZipArchive', '0.1.0' }
          target(:test, :exclusive => true) { pod 'JSONKit' }
          pod 'ASIHTTPRequest'
        end

        resolver = Pod::Resolver.new(podfile, nil, Pod::Sandbox.new(fixture('integration')))
        resolver = Pod::Resolver.new(podfile, nil, Pod::Sandbox.new(config.project_pods_root))
        installer = Pod::Installer.new(resolver)
        installer.install!

        project = Xcodeproj::Project.new(config.project_pods_root + 'Pods.xcodeproj')
        project.targets.each do |target|
          phase = target.build_phases.find { |phase| phase.is_a?(Xcodeproj::Project::Object::PBXSourcesBuildPhase) }
          files = phase.files.map(&:name)
          case target.product_name
          when 'Pods'
            files.should.include "ASIHTTPRequest.m"
            files.should.not.include "SSZipArchive.m"
            files.should.not.include "JSONKit.m"
          when 'Pods-debug'
            files.should.include "ASIHTTPRequest.m"
            files.should.include "SSZipArchive.m"
            files.should.not.include "JSONKit.m"
          when 'Pods-test'
            files.should.not.include "ASIHTTPRequest.m"
            files.should.not.include "SSZipArchive.m"
            files.should.include "JSONKit.m"
          else
            raise "ohnoes"
          end
        end

        root = config.project_pods_root
        (root + 'Pods.xcconfig').should.exist
        (root + 'Pods-debug.xcconfig').should.exist
        (root + 'Pods-test.xcconfig').should.exist
        (root + 'Pods-resources.sh').should.exist
        (root + 'Pods-debug-resources.sh').should.exist
        (root + 'Pods-test-resources.sh').should.exist

        should_xcodebuild(podfile.target_definitions[:default])
        should_xcodebuild(podfile.target_definitions[:debug])
        should_xcodebuild(podfile.target_definitions[:test])
      end

      it "sets up an existing project with pods" do
        config.integrate_targets = true

        basename = platform == :ios ? 'iPhone' : 'Mac'
        projpath = temporary_directory + 'ASIHTTPRequest.xcodeproj'
        FileUtils.cp_r(fixture("integration/ASIHTTPRequest/#{basename}.xcodeproj"), projpath)

        podfile = Pod::Podfile.new do
          self.platform platform
          xcodeproj projpath
          pod 'SSZipArchive', '0.1.0'
        end

        resolver = Pod::Resolver.new(podfile, nil, Pod::Sandbox.new(config.project_pods_root))
        installer = SpecHelper::Installer.new(resolver)
        installer.install!

        workspace = Xcodeproj::Workspace.new_from_xcworkspace(temporary_directory + 'ASIHTTPRequest.xcworkspace')
        workspace.projpaths.sort.should == ['ASIHTTPRequest.xcodeproj', 'Pods/Pods.xcodeproj']

        project = Pod::Project.new(projpath)
        libPods = project.files.find { |f| f.name == 'libPods.a' }

        target = project.targets.first
        target.build_configurations.each do |config|
          config.base_configuration.path.should == 'Pods/Pods.xcconfig'
        end
        target.frameworks_build_phases.first.files.should.include libPods
        # should be the last phase
        target.build_phases.last.shell_script.should == %{"${SRCROOT}/Pods/Pods-resources.sh"\n}
      end

      it "should prevent duplication cleaning headers symlinks with multiple targets" do
        podfile = Pod::Podfile.new do
          self.platform platform
          xcodeproj 'dummy'
          target(:debug) { pod 'SSZipArchive', '0.1.0' }
          target(:test, :exclusive => true) { pod 'JSONKit' }
          pod 'ASIHTTPRequest'
        end

        resolver = Pod::Resolver.new(podfile, nil, Pod::Sandbox.new(config.project_pods_root))
        installer = Pod::Installer.new(resolver)
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
