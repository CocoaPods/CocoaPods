require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Source::HealthReporter do
    before do
      WebMock::API.stub_request(:head, /banana-corp.local/).to_return(:status => 200)
      WebMock::API.stub_request(:head, /github.com/).to_return(:status => 200)
      @repo = fixture('spec-repos-core/test_repo')
      @reporter = Source::HealthReporter.new(@repo)
    end

    #-------------------------------------------------------------------------#

    describe 'In general' do
      it 'can store an option callback which is called before analyzing each specification' do
        names = []
        @reporter.pre_check do |name, _version|
          names << name
        end
        @reporter.analyze
        names.should.include?('BananaLib')
      end

      it 'analyzes all the specifications of a repo' do
        @reporter.analyze
        @reporter.report.analyzed_paths.count.should == 14
      end

      it 'is robust against malformed specifications' do
        @reporter.analyze
        errors = @reporter.report.pods_by_error.keys.join(' - ')
        errors.should.match /Faulty_spec.podspec.*could not be loaded/
      end

      it 'lints the specifications' do
        @reporter.analyze
        errors = @reporter.report.pods_by_error.keys.join(' - ')
        errors.should.match /Missing required attribute/
      end

      it 'checks the path of the specifications' do
        @reporter.analyze
        errors = @reporter.report.pods_by_error.keys.join("\n")
        errors.should.match /Incorrect path/
      end

      it 'checks if requires_arc has the string value of true or false' do
        @reporter.analyze
        warnings = @reporter.report.pods_by_warning.keys.join("\n")
        warnings.should.match /true is considered to be the name of a file/
      end

      it 'checks for any stray specifications' do
        @reporter.analyze
        errors = @reporter.report.pods_by_error.keys.join("\n")
        errors.should.match /Stray spec/
      end
    end

    #-------------------------------------------------------------------------#
  end
end
