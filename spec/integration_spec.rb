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
            source = spec.read(:source)
            source[:git] = SpecHelper.fixture("integration/#{spec.read(:name)}").to_s
            spec.source(source)
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
  describe "A full (integration spec) installation" do
    extend SpecHelper::TemporaryDirectory

    before do
      Pod::Source.reset!
      Pod::Spec::Set.reset!
      fixture('spec-repos/master') # ensure the archive is unpacked
      config.project_pods_root = temporary_directory + 'Pods'
      config.repos_dir = fixture('spec-repos')
    end

    after do
      config.project_pods_root = nil
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it "should activate required pods and create a working static library xcode project" do
      spec = Pod::Spec.new do
        dependency 'ASIWebPageRequest', '< 1.8.1'
        dependency 'JSONKit',           '>= 1.0'
        dependency 'SSZipArchive',      '< 2'
      end

      installer = SpecHelper::Installer.new(spec)
      installer.install!

      (config.project_pods_root + 'Reachability.podspec').should.exist
      (config.project_pods_root + 'ASIHTTPRequest.podspec').should.exist
      (config.project_pods_root + 'ASIWebPageRequest.podspec').should.exist
      (config.project_pods_root + 'JSONKit.podspec').should.exist
      (config.project_pods_root + 'SSZipArchive.podspec').should.exist

      puts "\n[!] Compiling static library..."
      Dir.chdir(config.project_pods_root) do
        system("xcodebuild > /dev/null 2>&1").should == true
      end
    end

    it "does not activate pods that are only part of other pods" do
      spec = Pod::Spec.new do
        dependency 'Reachability'
      end

      installer = SpecHelper::Installer.new(spec)
      installer.install!

      (config.project_pods_root + 'Reachability.podspec').should.exist
      (config.project_pods_root + 'ASIHTTPRequest.podspec').should.not.exist
    end
  end
end
