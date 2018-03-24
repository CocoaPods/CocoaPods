require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe ExternalSources::PathSource do
    before do
      params = { :path => fixture('integration/Reachability') }
      dependency = Dependency.new('Reachability', params)
      podfile_path = fixture('integration/Podfile')
      @subject = ExternalSources.from_dependency(dependency, podfile_path, true)
      config.sandbox.specifications_root.mkpath
    end

    it 'creates a copy of the podspec' do
      @subject.fetch(config.sandbox)
      path = config.sandbox.specifications_root + 'Reachability.podspec.json'
      path.should.exist?
    end

    it 'returns the description' do
      @subject.description.should.match /from `.*integration\/Reachability`/
    end

    it 'marks the Pod as local in the sandbox' do
      @subject.fetch(config.sandbox)
      config.sandbox.development_pods.should == {
        'Reachability' => fixture('integration/Reachability/Reachability.podspec'),
      }
    end

    it 'removes sandbox lockfile checkout options for the pod' do
      config.sandbox.store_checkout_source('Reachability', :http => 'https://example.com')
      @subject.fetch(config.sandbox)
      config.sandbox.checkout_sources['pod'].should.be.nil
    end

    it 'raises if the podspec cannot be found' do
      @subject.stubs(:params).returns(:path => temporary_directory)
      should.raise Informative do
        @subject.fetch(config.sandbox)
      end.message.should.match /No podspec found for `Reachability` in `#{temporary_directory}`/

      it 'marks a pod as relative' do
        @subject.stubs(:params).returns(:path => './Reachability')
        Pathname.any_instance.stubs(:exist?).returns(true)
        config.sandbox.stubs(:store_podspec)
        @subject.fetch(config.sandbox)
        config.sandbox.local_path_was_absolute?('Reachability').should.be.false
      end

      it 'marks a pod as absolute' do
        @subject.stubs(:params).returns(:path => fixture('integration/Reachability'))
        Pathname.any_instance.stubs(:exist?).returns(true)
        config.sandbox.stubs(:store_podspec)
        @subject.fetch(config.sandbox)
        config.sandbox.local_path_was_absolute?('Reachability').should.be.true
      end
    end

    describe '#podspec_path' do
      it 'handles absolute paths' do
        @subject.stubs(:params).returns(:path => fixture('integration/Reachability'))
        path = @subject.send(:podspec_path)
        path.should == fixture('integration/Reachability/Reachability.podspec')
      end

      it 'handles paths when there is no podfile path' do
        @subject.stubs(:podfile_path).returns(nil)
        @subject.stubs(:params).returns(:path => fixture('integration/Reachability'))
        path = @subject.send(:podspec_path)
        path.should == fixture('integration/Reachability/Reachability.podspec')
      end

      it 'handles relative paths' do
        @subject.stubs(:params).returns(:path => 'Reachability')
        path = @subject.send(:podspec_path)
        path.should == fixture('integration/Reachability/Reachability.podspec')
      end

      it 'expands the tilde' do
        File.stubs(:exist?).returns(true)
        @subject.stubs(:params).returns(:path => '~/Reachability')
        Pathname.any_instance.stubs(:exist?).returns(true)
        path = @subject.send(:podspec_path)
        path.should == Pathname(ENV['HOME']) + 'Reachability/Reachability.podspec'
      end

      it 'falls back to .podspec.json when .podspec doesnt exist' do
        @subject.stubs(:params).returns(:path => 'Reachability')
        Pathname.any_instance.stubs(:exist?).returns(false)
        path = @subject.send(:podspec_path)
        path.should == fixture('integration/Reachability/Reachability.podspec.json')
      end
    end

    describe '#absolute?' do
      it 'returns that a path is relative' do
        result = @subject.send(:absolute?, './ThirdPartyCode/UrbanAirship')
        result.should.be.false
      end

      it 'consider relative paths not explicitly set from the current dir' do
        result = @subject.send(:absolute?, './ThirdPartyCode/UrbanAirship')
        result.should.be.false
      end

      it 'returns that a path is absolute' do
        result = @subject.send(:absolute?, '/path/to/UrbanAirship')
        result.should.be.true
      end

      it 'considers absolute paths specified with the tilde' do
        result = @subject.send(:absolute?, '~/path/to/UrbanAirship')
        result.should.be.true
      end
    end
  end
end
