require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Sandbox::PodspecFinder do
    before do
      @root = Pathname(Dir.mktmpdir)
      @finder = Sandbox::PodspecFinder.new(@root)
    end

    after do
      @root.rmtree
    end

    it 'returns an empty hash when no podspecs are found' do
      @finder.podspecs.should.be.empty
    end

    it "warns when a found podspec can't be parsed" do
      @root.+('RestKit.podspec.json').open('w') { |f| f << '{]' }
      @finder.podspecs.should.be.empty
      UI.warnings.should.include "Unable to load a podspec from `RestKit.podspec.json`, skipping:\n\n"
    end

    it 'ignores podspecs not in the root' do
      path = @root + 'Dir/RestKit.podspec.json'
      path.parent.mkpath
      path.open('w') { |f| f << '{"name":"RestKit"}' }

      @finder.podspecs.should.be.empty
    end

    it 'groups found podspecs by name' do
      @root.+('Realm.podspec.json').open('w') { |f| f << '{"name":"Realm"}' }
      @root.+('RealmSwift.podspec').open('w') { |f| f << 'Pod::Specification.new { |s| s.name = "RealmSwift" }' }

      @finder.podspecs.should == {
        'Realm' => Pod::Specification.new { |s| s.name = 'Realm' },
        'RealmSwift' => Pod::Specification.new { |s| s.name = 'RealmSwift' },
      }
    end

    it 'caches the podspecs' do
      @finder.podspecs
      Pathname.expects(:glob).never
      @finder.podspecs
    end
  end
end
