require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Outdated do
    extend SpecHelper::TemporaryRepos

    before do
      Command::Outdated.any_instance.stubs(:unlocked_pods).returns([])
    end

    it 'tells the user that no Podfile was found in the project dir' do
      exception = lambda { run_command('outdated', '--no-repo-update') }.should.raise Informative
      exception.message.should.include "No `Podfile' found in the project directory."
    end

    it 'tells the user that no Lockfile was found in the project dir' do
      file = temporary_directory + 'Podfile'
      File.open(file, 'w') { |f| f.write('platform :ios') }
      Dir.chdir(temporary_directory) do
        exception = lambda { run_command('outdated', '--no-repo-update') }.should.raise Informative
        exception.message.should.include "No `Podfile.lock' found in the project directory"
      end
    end

    it 'tells the user only about podspecs that have no parent' do
      spec = Specification.new(nil, 'BlocksKit')
      subspec = Specification.new(spec, 'UIKit')
      set = mock
      set.stubs(:versions).returns(['2.0'])
      set.stubs(:specification).returns(spec)
      subset = mock
      subset.stubs(:specification).returns(subspec)
      subset.stubs(:versions).returns(['2.0'])
      version = mock
      version.stubs(:version).returns('1.0')
      Command::Outdated.any_instance.stubs(:spec_sets).returns([set, subset])
      Command::Outdated.any_instance.stubs(:lockfile).returns(version)
      run_command('outdated', '--no-repo-update')
      UI.output.should.not.include('UIKit')
    end

    it 'tells the user about deprecated pods' do
      spec = Specification.new(nil, 'AFNetworking')
      spec.deprecated_in_favor_of = 'BlocksKit'
      Command::Outdated.any_instance.stubs(:deprecated_pods).returns([spec])
      Command::Outdated.any_instance.stubs(:updates).returns([])
      run_command('outdated', '--no-repo-update')
      UI.output.should.include('in favor of BlocksKit')
    end

    it "updates the Podfile's sources by default" do
      podfile = Podfile.new do
        source 'https://github.com/CocoaPods/Specs.git'
        pod 'AFNetworking'
      end
      config.stubs(:podfile).returns(podfile)
      lockfile = mock
      lockfile.stubs(:version).returns(Version.new('1.0'))
      lockfile.stubs(:pod_names).returns(%w(AFNetworking))
      Command::Outdated.any_instance.stubs(:lockfile).returns(lockfile)
      config.sources_manager.expects(:update).once
      run_command('outdated')
    end

    it "doesn't updates the Podfile's sources with --no-repo-update" do
      config.stubs(:podfile).returns Podfile.new do
        source 'https://github.com/CocoaPods/Specs.git'
        pod 'AFNetworking'
      end
      lockfile = mock
      lockfile.stubs(:version).returns(Version.new('1.0'))
      lockfile.stubs(:pod_names).returns(%w(AFNetworking))
      Command::Outdated.any_instance.stubs(:lockfile).returns(lockfile)
      config.sources_manager.expects(:update).never
      run_command('outdated', '--no-repo-update')
    end

    it 'tells the user to run `pod install` when external sources need to be fetched' do
      lockfile = mock('Lockfile')
      lockfile.stubs(:version).returns(Version.new('1.0'))
      lockfile.stubs(:pod_names).returns(%w(AFNetworking))
      config.stubs(:lockfile).returns(lockfile)
      podfile = Podfile.new do
        pod 'AFNetworking', :git => 'https://github.com/AFNetworking/AFNetworking.git'
      end
      config.stubs(:podfile).returns(podfile)
      exception = lambda { run_command('outdated', '--no-repo-update') }.should.raise Informative
      exception.message.should.include 'You must run `pod install` first to ensure that the podspec for `AFNetworking` has been fetched.'
    end
  end
end
