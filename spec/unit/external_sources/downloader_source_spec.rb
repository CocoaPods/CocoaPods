require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe ExternalSources::DownloaderSource do
    before do
      params = {
        :git => fixture('integration/Reachability'),
        :branch => 'master',
      }
      dep = Dependency.new('Reachability', params)
      @subject = ExternalSources.from_dependency(dep, nil, true)
      config.sandbox.specifications_root.mkpath
    end

    it 'creates a copy of the podspec' do
      @subject.fetch(config.sandbox)
      path = config.sandbox.specifications_root + 'Reachability.podspec.json'
      path.should.exist?
    end

    it 'marks the Pod as pre-downloaded' do
      @subject.fetch(config.sandbox)
      config.sandbox.predownloaded_pods.should == ['Reachability']
    end

    it 'returns the description' do
      expected = /from `.*Reachability`, branch `master`/
      @subject.description.should.match(expected)
    end
  end
end
