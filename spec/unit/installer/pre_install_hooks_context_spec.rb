require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::PreInstallHooksContext do
    it 'offers a convenience method to be generated' do
      sandbox = stub(:root => Pathname('root'))
      podfile = stub
      lockfile = stub

      result = Installer::PreInstallHooksContext.generate(sandbox, podfile, lockfile)
      result.class.should == Installer::PreInstallHooksContext
      result.sandbox.should == sandbox
      result.sandbox_root == 'root'
      result.podfile.should == podfile
      result.lockfile.should == lockfile
    end
  end
end
