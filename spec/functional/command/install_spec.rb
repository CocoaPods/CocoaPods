require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Install do
    it 'tells the user that no Podfile or podspec was found in the project dir' do
      exception = lambda { run_command('install', '--no-repo-update') }.should.raise Informative
      exception.message.should.include "No `Podfile' found in the project directory."
    end

    it "doesn't update the spec repos by default" do
      config.with_changes(:skip_repo_update => nil) do
        Pod::Command.parse(['install'])
        config.skip_repo_update.should.be.true
      end
    end

    it 'updates the spec repos if that option was given' do
      config.with_changes(:skip_repo_update => nil) do
        Pod::Command.parse(['install', '--repo-update'])
        config.skip_repo_update.should.be.false
      end
    end
  end
end
