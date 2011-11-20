require File.expand_path('../spec_helper', __FILE__)
require 'yaml'

module SpecHelper
  class Installer < Pod::Installer
    # Here we override the `source' of the pod specifications to point to the integration fixtures.
    def dependent_specification_sets
      @dependent_specification_sets ||= super
      @dependent_specification_sets.each do |set|
        def set.specification
          spec = super
          unless spec.part_of_other_pod?
            source = spec.source
            source[:git] = SpecHelper.fixture("integration/#{spec.name}").to_s
            spec.source = source
          end
          spec
        end
      end
      @dependent_specification_sets
    end
  end
end

unless SpecHelper.fixture('integration/ASIHTTPRequest/Classes').exist?
  puts "[!] You must run `git submodule update --init` for the integration spec to work, skipping."
else
  [:ios, :osx].each do |platform|
    describe "A full (integration spec) installation for platform `#{platform}'" do
      extend SpecHelper::TemporaryDirectory

      before do
        Pod::Source.reset!
        Pod::Spec::Set.reset!
        fixture('spec-repos/master') # ensure the archive is unpacked

        @config_before = config
        Pod::Config.instance = nil
        config.silent = true
        config.repos_dir = fixture('spec-repos')
        config.project_root = temporary_directory
      end

      after do
        Pod::Config.instance = @config_before
      end

      def should_successfully_perform(command)
        output = `#{command} 2>&1`
        puts output unless $?.success?
        $?.should.be.success
      end

      # Lame way to run on one platform only
      if platform == :ios
        it "installs a Pod directly from its repo" do
          url = fixture('integration/sstoolkit').to_s
          commit = '2adcd0f81740d6b0cd4589af98790eee3bd1ae7b'
          podfile = Pod::Podfile.new do
            self.platform :ios
            dependency 'SSToolkit', :git => url, :commit => commit
          end

          # Note that we are *not* using the stubbed SpecHelper::Installer subclass.
          installer = Pod::Installer.new(podfile)
          installer.install!

          YAML.load(installer.lock_file.read).should == {
            'PODS' => ['SSToolkit (0.1.3)'],
            'DEPENDENCIES' => ["SSToolkit (from `#{url}', commit `#{commit}')"]
          }

          Dir.chdir(config.project_pods_root + 'SSToolkit') do
            `git config --get remote.origin.url`.strip.should == url
          end
        end

        it "installs a library with a podspec outside of the repo" do
          url = 'https://raw.github.com/gist/1349824/3ec6aa60c19113573fc48eac19d0fafd6a69e033/Reachability.podspec'
          podfile = Pod::Podfile.new do
            self.platform :ios
            # TODO use a local file instead of http?
            dependency 'Reachability', :podspec => url
          end

          installer = SpecHelper::Installer.new(podfile)
          installer.install!

          YAML.load(installer.lock_file.read).should == {
            'PODS' => [{ 'Reachability (1.2.3)' => ["ASIHTTPRequest (>= 1.8)"] }],
            'DOWNLOAD_ONLY' => ["ASIHTTPRequest (1.8.1)"],
            'DEPENDENCIES' => ["Reachability (from `#{url}')"]
          }
        end

        it "installs a library with a podspec defined inline" do
          podfile = Pod::Podfile.new do
            self.platform :ios
            dependency do |s|
              s.name         = 'JSONKit'
              s.version      = '1.2'
              s.source       = { :git => SpecHelper.fixture('integration/JSONKit').to_s, :tag => 'v1.2' }
              s.source_files = 'JSONKit.*'
            end
            dependency do |s|
              s.name         = 'SSZipArchive'
              s.version      = '0.1.0'
              s.source       = { :git => SpecHelper.fixture('integration/SSZipArchive').to_s, :tag => '0.1.0' }
              s.source_files = 'SSZipArchive.*', 'minizip/*.{h,c}'
            end
          end

          installer = SpecHelper::Installer.new(podfile)
          installer.install!

          YAML.load(installer.lock_file.read).should == {
            'PODS' => ['JSONKit (1.2)', 'SSZipArchive (0.1.0)'],
            'DEPENDENCIES' => ["JSONKit (defined in Podfile)", "SSZipArchive (defined in Podfile)"]
          }

          change_log = (config.project_pods_root + 'JSONKit/CHANGELOG.md').read
          change_log.should.include '1.2'
          change_log.should.not.include '1.3'
        end
      end

      before do
        FileUtils.cp_r(fixture('integration/.'), config.project_pods_root)
      end

      it "runs the optional post_install callback defined in the Podfile _before_ the project is saved to disk" do
        podfile = Pod::Podfile.new do
          config.rootspec = self
          self.platform platform
          dependency 'SSZipArchive'

          post_install do |installer|
            target = installer.project.targets.first
            target.buildConfigurations.each do |config|
              config.buildSettings['GCC_ENABLE_OBJC_GC'] = 'supported'
            end
          end
        end

        SpecHelper::Installer.new(podfile).install!
        project = Xcodeproj::Project.new(config.project_pods_root + 'Pods.xcodeproj')
        project.targets.first.buildConfigurations.map do |config|
          config.buildSettings['GCC_ENABLE_OBJC_GC']
        end.should == %w{ supported supported }
      end

      # TODO add a simple source file which uses the compiled lib to check that it really really works
      it "should activate required pods and create a working static library xcode project" do
        spec = Pod::Podfile.new do
          # first ensure that the correct info is available to the specs when they load
          config.rootspec = self

          self.platform platform
          dependency 'Reachability',      '< 2.0.5' if platform == :ios
          dependency 'ASIWebPageRequest', '>= 1.8.1'
          dependency 'JSONKit',           '>= 1.0'
          dependency 'SSZipArchive',      '< 2'
        end

        installer = SpecHelper::Installer.new(spec)
        installer.install!

        lock_file_contents = {
          'PODS' => [
            { 'ASIHTTPRequest (1.8.1)'    => ["Reachability (~> 2.0, >= 2.0.4)"] },
            { 'ASIWebPageRequest (1.8.1)' => ["ASIHTTPRequest (= 1.8.1)"] },
            'JSONKit (1.4)',
            { 'Reachability (2.0.4)'      => ["ASIHTTPRequest (>= 1.8)"] },
            'SSZipArchive (0.1.1)',
          ],
          'DEPENDENCIES' => [
            "ASIWebPageRequest (>= 1.8.1)",
            "JSONKit (>= 1.0)",
            "Reachability (< 2.0.5)",
            "SSZipArchive (< 2)",
          ]
        }
        unless platform == :ios
          # No Reachability is required by ASIHTTPRequest on OSX
          lock_file_contents['DEPENDENCIES'].delete_at(2)
          lock_file_contents['PODS'].delete_at(3)
          lock_file_contents['PODS'][0] = 'ASIHTTPRequest (1.8.1)'
        end
        YAML.load(installer.lock_file.read).should == lock_file_contents

        root = config.project_pods_root
        (root + 'Pods.xcconfig').read.should == installer.target_installers.first.xcconfig.to_s
        project_file = (root + 'Pods.xcodeproj/project.pbxproj').to_s
        NSDictionary.dictionaryWithContentsOfFile(project_file).should == installer.project.to_hash

        puts "\n[!] Compiling static library..."
        Dir.chdir(config.project_pods_root) do
          should_successfully_perform "xcodebuild"
        end
      end

      if platform == :ios
        it "does not activate pods that are only part of other pods" do
          spec = Pod::Podfile.new do
            # first ensure that the correct info is available to the specs when they load
            config.rootspec = self

            self.platform platform
            dependency 'Reachability', '2.0.4' # only 2.0.4 is part of ASIHTTPRequest’s source.
          end

          installer = SpecHelper::Installer.new(spec)
          installer.install!

          YAML.load(installer.lock_file.read).should == {
            'PODS' => [{ 'Reachability (2.0.4)' => ["ASIHTTPRequest (>= 1.8)"] }],
            'DOWNLOAD_ONLY' => ["ASIHTTPRequest (1.8.1)"],
            'DEPENDENCIES' => ["Reachability (= 2.0.4)"]
          }
        end
      end

      it "adds resources to the xcode copy script" do
        spec = Pod::Podfile.new do
          # first ensure that the correct info is available to the specs when they load
          config.rootspec = self

          self.platform platform
          dependency 'SSZipArchive'
        end

        installer = SpecHelper::Installer.new(spec)
        installer.target_installers.first.build_specifications.first.resources = 'LICEN*', 'Readme.*'
        installer.install!

        contents = (config.project_pods_root + 'Pods-resources.sh').read
        contents.should.include "install_resource 'SSZipArchive/LICENSE'\n" \
                                "install_resource 'SSZipArchive/Readme.markdown'"
      end

      # TODO we need to do more cleaning and/or add a --prune task
      it "overwrites an existing project.pbxproj file" do
        spec = Pod::Podfile.new do
          # first ensure that the correct info is available to the specs when they load
          config.rootspec = self

          self.platform platform
          dependency 'JSONKit'
        end
        installer = SpecHelper::Installer.new(spec)
        installer.install!

        Pod::Source.reset!
        Pod::Spec::Set.reset!
        spec = Pod::Podfile.new do
          # first ensure that the correct info is available to the specs when they load
          config.rootspec = self

          self.platform platform
          dependency 'SSZipArchive'
        end
        installer = SpecHelper::Installer.new(spec)
        installer.install!

        project = Xcodeproj::Project.new(config.project_pods_root + 'Pods.xcodeproj')
        project.source_files.should == installer.project.source_files
      end

      it "creates a project with multiple targets" do
        Pod::Source.reset!
        Pod::Spec::Set.reset!

        podfile = Pod::Podfile.new do
          # first ensure that the correct info is available to the specs when they load
          config.rootspec = self
          self.platform platform
          target(:debug) { dependency 'SSZipArchive' }
          target(:test, :exclusive => true) { dependency 'JSONKit' }
          dependency 'ASIHTTPRequest'
        end

        installer = Pod::Installer.new(podfile)
        installer.install!

        #project = Pod::Xcode::Project.new(config.project_pods_root + 'Pods.xcodeproj')
        #p project
        #project.targets.each do |target|
          #target.source_build_phases.
        #end

        root = config.project_pods_root
        (root + 'Pods.xcconfig').should.exist
        (root + 'Pods-debug.xcconfig').should.exist
        (root + 'Pods-test.xcconfig').should.exist
        (root + 'Pods-resources.sh').should.exist
        (root + 'Pods-debug-resources.sh').should.exist
        (root + 'Pods-test-resources.sh').should.exist

        Dir.chdir(config.project_pods_root) do
          puts "\n[!] Compiling static library `Pods'..."
          should_successfully_perform "xcodebuild -target Pods"
          puts "\n[!] Compiling static library `Pods-debug'..."
          should_successfully_perform "xcodebuild -target Pods-debug"
          puts "\n[!] Compiling static library `Pods-test'..."
          should_successfully_perform "xcodebuild -target Pods-test"
        end
      end

      it "sets up an existing project with pods" do
        basename = platform == :ios ? 'iPhone' : 'Mac'
        projpath = temporary_directory + 'ASIHTTPRequest.xcodeproj'
        FileUtils.cp_r(fixture("integration/ASIHTTPRequest/#{basename}.xcodeproj"), projpath)
        spec = Pod::Podfile.new do
          self.platform platform
          dependency 'SSZipArchive'
        end
        installer = SpecHelper::Installer.new(spec)
        installer.install!
        installer.configure_project(projpath)

        xcworkspace = temporary_directory + 'ASIHTTPRequest.xcworkspace'
        workspace = Xcodeproj::Workspace.new_from_xcworkspace(xcworkspace)
        workspace.projpaths.sort.should == ['ASIHTTPRequest.xcodeproj', 'Pods/Pods.xcodeproj']

        project = Xcodeproj::Project.new(projpath)
        libPods = project.files.find { |f| f.name == 'libPods.a' }
        project.targets.each do |target|
          target.buildConfigurations.each do |config|
            config.baseConfiguration.path.should == 'Pods/Pods.xcconfig'
          end

          phase = target.frameworks_build_phases.first
          phase.files.map { |buildFile| buildFile.file }.should.include libPods

          # should be the last phase
          target.buildPhases.last.shellScript.should == %{"${SRCROOT}/Pods/Pods-resources.sh"\n}
        end
      end

    end
  end

end
