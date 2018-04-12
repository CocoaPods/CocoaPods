require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe ExternalSources::AbstractExternalSource do
    before do
      dependency = Dependency.new('Reachability', :git => fixture('integration/Reachability'))
      @subject = ExternalSources.from_dependency(dependency, nil, true)
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

      it 'raises appropriate error if a DSLError was raised' do
        Downloader.stubs(:download).raises(Pod::DSLError.new('Invalid `Reachability.podspec` file:', 'some/path/to/podspec', Exception.new('Error Message')))
        should.raise(Informative) do
          e = @subject.send(:pre_download, config.sandbox)
          e.message.should.include "Failed to load 'Reachability' podspec:"
          e.message.should.include 'Invalid `Reachability.podspec` file:'
        end
      end

      it 'raises a generic error if pre download fails' do
        Downloader.stubs(:download).raises(Pod::Downloader::DownloaderError.new('Some generic exception'))
        exception = lambda { @subject.send(:pre_download, config.sandbox) }.should.raise Informative
        exception.message.should.include "Failed to download 'Reachability'"
      end

      it 'raises appropriate error if a DSLError when storing a podspec from string' do
        podspec = 'Pod::Spec.new do |s|; error; end'
        should.raise(Informative) { @subject.send(:store_podspec, config.sandbox, podspec) }.
            message.should.include "Invalid `Reachability.podspec` file: undefined local variable or method `error'"
      end

      it 'raises appropriate error if a DSLError when storing a podspec from file' do
        podspec = 'Pod::Spec.new do |s|; error; end'
        path = SpecHelper.temporary_directory + 'BananaLib.podspec'
        File.open(path, 'w') { |f| f.write(podspec) }
        should.raise(Informative) { @subject.send(:store_podspec, config.sandbox, path) }.
            message.should.include "Invalid `BananaLib.podspec` file: undefined local variable or method `error'"
      end

      it 'raises a generic error if a podspec was not found' do
        download_result = stub(:spec => nil)
        Downloader.stubs(:download).returns(download_result)
        exception = lambda { @subject.send(:pre_download, config.sandbox) }.should.raise Informative
        exception.message.should.include "Unable to find a specification for 'Reachability'."
      end
    end

    #--------------------------------------#

    describe 'Subclasses helpers' do
      it 'pre-downloads the Pod and stores the relevant information in the sandbox' do
        @subject.expects(:validate_podspec).with do |spec|
          spec.name.should == 'Reachability'
        end
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

      describe 'podspec validation' do
        before do
          @podspec = Pod::Specification.from_file(fixture('spec-repos') + 'master/Specs/1/3/f/JSONKit/1.4/JSONKit.podspec.json')
        end

        it 'returns a validator for the given podspec' do
          validator = @subject.send(:validator_for_podspec, @podspec)
          validator.spec.should == @podspec
        end

        before do
          @validator = mock('Validator')
          @validator.expects(:quick=).with(true)
          @validator.expects(:allow_warnings=).with(true)
          @validator.expects(:ignore_public_only_results=).with(true)
          @validator.expects(:validate)
          @subject.stubs(:validator_for_podspec).returns(@validator)
        end

        it 'validates with the correct settings' do
          @validator.expects(:validated?).returns(true)
          @subject.send(:validate_podspec, @podspec)
        end

        it 'raises when validation fails' do
          @validator.expects(:validated?).returns(false)
          @validator.stubs(:results_message).returns('results_message')
          @validator.stubs(:failure_reason).returns('failure_reason')
          should.raise(Informative) { @subject.send(:validate_podspec, @podspec) }.
            message.should.include "The `Reachability` pod failed to validate due to failure_reason:\nresults_message"
        end
      end
    end
  end
end
