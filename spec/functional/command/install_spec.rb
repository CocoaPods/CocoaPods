require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Install do
    it 'tells the user that no Podfile or podspec was found in the project dir' do
      exception = lambda { run_command('install') }.should.raise Informative
      exception.message.should.include "No `Podfile' found in the project directory."
    end

    describe 'updates of the spec repos' do
      before do
        file = temporary_directory + 'Podfile'
        File.open(file, 'w') do |f|
          f.puts('platform :ios')
          f.puts('pod "Reachability"')
        end
        Installer.any_instance.expects(:install!)
      end

      it "doesn't update the spec repos by default" do
        Installer.any_instance.expects(:repo_update=).with(false)
        run_command('install')
      end

      it 'updates the spec repos if that option was given' do
        Installer.any_instance.expects(:repo_update=).with(true)
        run_command('install', '--repo-update')
      end
    end
  end
end
