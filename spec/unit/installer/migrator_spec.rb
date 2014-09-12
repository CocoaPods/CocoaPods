require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::Migrator do
    it "doesn't perform migrations if they are not needed" do
      manifest = stub(:cocoapods_version => Version.new('999'))
      config.sandbox.stubs(:manifest).returns(manifest)
      Installer::Migrator.expects(:migrate_to_0_34).never
      Installer::Migrator.migrate(config.sandbox)
    end
  end
end
