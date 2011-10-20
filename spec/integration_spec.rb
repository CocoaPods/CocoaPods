require File.expand_path('../spec_helper', __FILE__)

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
        config.repos_dir = fixture('spec-repos')
        config.project_pods_root = temporary_directory + 'Pods'
        FileUtils.cp_r(fixture('integration/.'), config.project_pods_root)
      end

      after do
        config.project_pods_root = nil
        config.repos_dir = SpecHelper.tmp_repos_path
      end

      # TODO add a simple source file which uses the compiled lib to check that it really really works
      it "should activate required pods and create a working static library xcode project" do
        spec = Pod::Podfile.new do
          self.platform platform
          dependency 'ASIWebPageRequest', '>= 1.8.1'
          dependency 'JSONKit',           '>= 1.0'
          dependency 'SSZipArchive',      '< 2'
        end

        installer = SpecHelper::Installer.new(spec)
        installer.install!

        root = config.project_pods_root
        (root + 'Reachability.podspec').should.exist
        (root + 'ASIHTTPRequest.podspec').should.exist
        (root + 'ASIWebPageRequest.podspec').should.exist
        (root + 'JSONKit.podspec').should.exist
        (root + 'SSZipArchive.podspec').should.exist

        (root + 'Pods.xcconfig').read.should == installer.xcconfig.to_s

        project_file = (root + 'Pods.xcodeproj/project.pbxproj').to_s
        NSDictionary.dictionaryWithContentsOfFile(project_file).should == installer.xcodeproj.to_hash

        #puts "\n[!] Compiling static library..."
        #Dir.chdir(config.project_pods_root) do
          #system("xcodebuild > /dev/null 2>&1").should == true
          #system("xcodebuild").should == true
        #end
      end

      it "does not activate pods that are only part of other pods" do
        spec = Pod::Podfile.new do
          self.platform platform
          dependency 'Reachability'
        end

        installer = SpecHelper::Installer.new(spec)
        installer.install!

        (config.project_pods_root + 'Reachability.podspec').should.exist
        (config.project_pods_root + 'ASIHTTPRequest.podspec').should.not.exist
      end

      it "adds resources to the xcode copy script" do
        spec = Pod::Podfile.new do
          self.platform platform
          dependency 'SSZipArchive'
        end

        installer = SpecHelper::Installer.new(spec)
        dependency_spec = installer.build_specifications.first
        dependency_spec.resources = 'LICEN*', 'Readme.*'
        installer.install!

        contents = (config.project_pods_root + 'PodsResources.sh').read
        contents.should.include "install_resource 'SSZipArchive/LICENSE'\n" \
                                "install_resource 'SSZipArchive/Readme.markdown'"
      end

      # TODO we need to do more cleaning and/or add a --prune task
      it "overwrites an existing project.pbxproj file" do
        spec = Pod::Podfile.new do
          self.platform platform
          dependency 'JSONKit'
        end
        installer = SpecHelper::Installer.new(spec)
        installer.install!

        Pod::Source.reset!
        Pod::Spec::Set.reset!
        spec = Pod::Podfile.new do
          self.platform platform
          dependency 'SSZipArchive'
        end
        installer = SpecHelper::Installer.new(spec)
        installer.install!

        installer = Pod::Installer.new(spec)
        installer.generate_project
        project = Pod::Xcode::Project.new(config.project_pods_root)
        project.source_files.should == installer.xcodeproj.source_files
      end
    end
  end
end
