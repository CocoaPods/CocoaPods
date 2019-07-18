require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  describe Specification::Set::Presenter do
    describe 'Set Information' do
      before do
        sources = [TrunkSource.new(fixture('spec-repos-core/trunk')), Source.new(fixture('spec-repos-core/test_repo'))]
        sets = Source::Aggregate.new(sources).search_by_name('JSONKit')
        set = sets.find { |s| s.name == 'JSONKit' }
        @presenter = Spec::Set::Presenter.new(set)
      end

      it 'returns the set used to initialize it' do
        @presenter.set.class.should == Specification::Set
        @presenter.set.name.should == 'JSONKit'
      end

      it 'returns the name' do
        @presenter.name.should == 'JSONKit'
      end

      it 'returns the version' do
        @presenter.version.should == Version.new('999.999.999')
      end

      it 'returns all the version sorted from the highest to the lowest' do
        @presenter.versions.map(&:to_s).should == ['999.999.999', '1.13', '1.5pre', '1.4']
        @presenter.versions.last.class.should == Version
      end

      it 'returns the versions by source' do
        @presenter.versions_by_source.should == '999.999.999, 1.13, 1.4 [test_repo repo] - 1.5pre, 1.4 [trunk repo]'
      end

      it 'returns the sources' do
        @presenter.sources.should == %w(test_repo trunk)
      end

      it 'returns the correct deprecation description' do
        @presenter.deprecation_description.should.nil?
        @presenter.spec.deprecated = true
        @presenter.deprecation_description.should == '[DEPRECATED]'
        @presenter.spec.deprecated_in_favor_of = 'NewMoreAwesomePod'
        @presenter.deprecation_description.should == '[DEPRECATED in favor of NewMoreAwesomePod]'
      end
    end

    describe 'Specification Information' do
      before do
        @source = TrunkSource.new(fixture('spec-repos-core/trunk'))
        set = Spec::Set.new('CocoaLumberjack', @source)
        @presenter = Spec::Set::Presenter.new(set)
      end

      it 'returns the specification' do
        @presenter.spec.class.should == Specification
        @presenter.spec.name.should == 'CocoaLumberjack'
      end

      it 'returns the specification authors' do
        @presenter.authors.should == 'Robbie Hanson'
        @presenter.spec.authors = ['Author 1', 'Author 2']
        @presenter.authors.should == 'Author 1 and Author 2'
        @presenter.spec.authors = ['Author 1', 'Author 2', 'Author 3']
        @presenter.authors.should == 'Author 1, Author 2, and Author 3'
      end

      it 'returns the homepage' do
        @presenter.homepage.should == 'https://github.com/CocoaLumberjack/CocoaLumberjack'
      end

      it 'returns the description' do
        @presenter.description.should == 'It is similar in concept to other popular ' \
          'logging frameworks such as log4j, yet is designed specifically for '       \
          'objective-c, and takes advantage of features such as multi-threading, '    \
          'grand central dispatch (if available), lockless atomic operations, and '   \
          'the dynamic nature of the objective-c runtime.'
      end

      it 'returns the summary' do
        @presenter.summary.should == 'A fast & simple, yet powerful & flexible logging framework for Mac and iOS.'
      end

      it 'returns the source_url' do
        @presenter.source_url.should == 'https://github.com/CocoaLumberjack/CocoaLumberjack.git'
      end

      it 'returns the platform' do
        @presenter.platform.should == 'iOS 8.0 - macOS 10.10 - tvOS 9.0 - watchOS 3.0'
      end

      it 'returns the license' do
        @presenter.license.should == 'BSD'
      end

      it 'returns the subspecs' do
        @presenter.subspecs.map(&:name).should == ['CocoaLumberjack/Core', 'CocoaLumberjack/Swift']

        set = Spec::Set.new('RestKit', @source)
        @presenter = Spec::Set::Presenter.new(set)
        subspecs = @presenter.subspecs
        subspecs.last.class.should == Specification
        subspecs.map(&:name).should == ['RestKit/Core', 'RestKit/ObjectMapping', 'RestKit/Network', 'RestKit/CoreData', 'RestKit/Testing',
                                        'RestKit/Search', 'RestKit/Support', 'RestKit/CocoaLumberjack']
      end
    end

    describe 'Statistics' do
      before do
        @source = TrunkSource.new(fixture('spec-repos-core/trunk'))
        set = Spec::Set.new('CocoaLumberjack', @source)
        metrics = {
          'github' => {
            'contributors' => 30,
            'created_at' => '2014-06-11 16:40:13 UTC',
            'forks' => 1726,
            'open_issues' => 242,
            'open_pull_requests' => 30,
            'stargazers' => 7188,
            'subscribers' => 425,
            'updated_at' => '2014-12-03 01:27:55 UTC',
          },
        }
        Metrics.stubs(:pod).returns(metrics)
        @presenter = Spec::Set::Presenter.new(set)
      end

      it 'returns the GitHub stars' do
        @presenter.github_stargazers.should == 7188
      end

      it 'returns the GitHub forks' do
        @presenter.github_forks.should == 1726
      end
    end
  end
end
