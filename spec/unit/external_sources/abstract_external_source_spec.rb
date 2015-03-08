require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe ExternalSources::AbstractExternalSource do
    before do
      dependency = Dependency.new('Reachability', :git => fixture('integration/Reachability'))
      @subject = ExternalSources.from_dependency(dependency, nil)
      config.sandbox.prepare
    end

    #--------------------------------------#

    describe 'In general' do
      it 'compares to another' do
        dependency_1 = Dependency.new('Reachability', :git => 'url')
        dependency_2 = Dependency.new('Another_name', :git => 'url')
        dependency_3 = Dependency.new('Reachability', :git => 'another_url')

        dependency_1.should.be == dependency_1
        dependency_1.should.not.be == dependency_2
        dependency_1.should.not.be == dependency_3
      end

      it 'fetches the specification from the remote stores it in the sandbox' do
        config.sandbox.specification('Reachability').should.nil?
        @subject.fetch(config.sandbox)
        config.sandbox.specification('Reachability').name.should == 'Reachability'
      end
    end

    #--------------------------------------#

    describe 'Subclasses helpers' do
      it 'pre-downloads the Pod and stores the relevant information in the sandbox' do
        @subject.send(:pre_download, config.sandbox)
        path = config.sandbox.specifications_root + 'Reachability.podspec.json'
        path.should.exist?
        config.sandbox.predownloaded_pods.should == ['Reachability']
        config.sandbox.checkout_sources.should == {
          'Reachability' => {
            :git => fixture('integration/Reachability'),
            :commit => '4ec575e4b074dcc87c44018cce656672a979b34a',
          },
        }
      end

      it 'checks for JSON podspecs' do
        path = config.download_cache.send(:path_for_pod, 'Reachability', nil, @subject.params)
        podspec_path = path + 'Reachability.podspec.json'
        path.mkpath
        File.open(podspec_path, 'w') { |f| f.write '{"name":"Reachability"}' }
        Pathname.any_instance.stubs(:rmtree)
        Downloader::Git.any_instance.stubs(:download)
        config.sandbox.expects(:store_podspec).with('Reachability', %({\n  "name": "Reachability"\n}\n), true, true)
        @subject.send(:pre_download, config.sandbox)
      end
    end
  end
end
