require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::Migrator do
    it 'performs a migration' do
      manifest = stub(:cocoapods_version => Version.new('0.32'))
      config.sandbox.stubs(:manifest).returns(manifest)
      old_path = config.sandbox.root + 'ARAnalytics'
      old_path.mkdir
      Installer::Migrator.migrate(config.sandbox)
      old_path.should.not.exist?
      (config.sandbox.sources_root + 'ARAnalytics').should.exist?
    end

    it "doesn't perform migrations if they are not needed" do
      manifest = stub(:cocoapods_version => Version.new('999'))
      config.sandbox.stubs(:manifest).returns(manifest)
      Installer::Migrator.expects(:migrate_to_0_34).never
      Installer::Migrator.migrate(config.sandbox)
    end
  end
end
