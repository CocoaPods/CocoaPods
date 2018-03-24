require File.expand_path('../../../spec_helper', __FILE__)
require 'webmock'

module Pod
  describe ExternalSources::PodspecSource do
    before do
      podspec_path = fixture('integration/Reachability/Reachability.podspec')
      dependency = Dependency.new('Reachability', :podspec => podspec_path.to_s)
      podfile_path = fixture('integration/Podfile')
      @subject = ExternalSources.from_dependency(dependency, podfile_path, true)
    end

    it 'creates a copy of the podspec' do
      config.sandbox.specifications_root.mkpath
      @subject.fetch(config.sandbox)
      path = config.sandbox.specifications_root + 'Reachability.podspec.json'
      path.should.exist?
    end

    it 'returns the description' do
      @subject.description.should.match /from `.*Reachability\/Reachability.podspec`/
    end

    describe 'Helpers' do
      it 'handles absolute paths' do
        @subject.stubs(:params).returns(:podspec => fixture('integration/Reachability'))
        path = @subject.send(:podspec_uri)
        path.should == fixture('integration/Reachability/Reachability.podspec').to_s
      end

      it 'handles paths when there is no podfile path' do
        @subject.stubs(:podfile_path).returns(nil)
        @subject.stubs(:params).returns(:podspec => fixture('integration/Reachability'))
        path = @subject.send(:podspec_uri)
        path.should == fixture('integration/Reachability/Reachability.podspec').to_s
      end

      it 'handles relative paths' do
        @subject.stubs(:params).returns(:podspec => 'Reachability')
        path = @subject.send(:podspec_uri)
        path.should == fixture('integration/Reachability/Reachability.podspec').to_s
      end

      it 'expands the tilde' do
        File.stubs(:exist?).returns(true)
        @subject.stubs(:params).returns(:podspec => '~/Reachability')
        path = @subject.send(:podspec_uri)
        path.should == ENV['HOME'] + '/Reachability/Reachability.podspec'
      end

      it 'handles URLs' do
        @subject.stubs(:params).returns(:podspec => 'http://www.example.com/Reachability.podspec')
        path = @subject.send(:podspec_uri)
        path.should == 'http://www.example.com/Reachability.podspec'
      end
    end

    describe 'http source' do
      it 'raises an Informative error if the specified url fails to load' do
        @subject.stubs(:params).returns(:podspec => 'https://github.com/username/TSMessages/TSMessages.podspec')
        WebMock.enable!
        WebMock::API.stub_request(:get, 'https://github.com/username/TSMessages/TSMessages.podspec').
          to_return(:status => 404)

        lambda { @subject.fetch(config.sandbox) }.should.raise(Informative).
          message.should.match(/Failed to fetch podspec for/)
        WebMock.reset!
      end
    end
  end
end
