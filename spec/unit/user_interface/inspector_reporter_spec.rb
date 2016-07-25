require File.expand_path('../../../spec_helper', __FILE__)
require 'gh_inspector'

# A quiet version of Evidence, so tests don't echo
class SilentEvidence
  def inspector_started_query(query, inspector); end

  def inspector_is_still_investigating(query, inspector); end

  def inspector_successfully_recieved_report(report, inspector); end

  def inspector_recieved_empty_report(report, inspector); end

  def inspector_could_not_create_report(error, query, inspector); end
end

module Pod
  describe UserInterface::InspectorReporter do
    it 'handles inspector_started_query' do
      inspector = GhInspector::Inspector.new 'cocoapods', 'cocoapods'
      reporter = UserInterface::InspectorReporter.new
      reporter.inspector_started_query('query', inspector)

      UI.output.should.match %r{Looking for related issues on cocoapods\/cocoapods}
    end

    it 'handles inspector_successfully_recieved_report' do
      url = 'https://api.github.com/search/issues?q=Testing+repo:cocoapods/cocoapods'
      fixture_json_text = File.read SpecHelper.fixture('github_search_response.json')
      GhInspector::Sidekick.any_instance.expects(:get_api_results).with(url).returns(JSON.parse(fixture_json_text))

      inspector = GhInspector::Inspector.new 'cocoapods', 'cocoapods'
      report = inspector.search_query 'Testing', SilentEvidence.new

      reporter = UserInterface::InspectorReporter.new
      reporter.inspector_successfully_recieved_report(report, inspector)

      UI.output.should.match /Travis CI with Ruby 1.9.x fails for recent pull requests/
      UI.output.should.match %r{https:\/\/github.com\/CocoaPods\/CocoaPods\/issues\/646 \[closed\] \[8 comments\]}
      UI.output.should.match /pod search --full chokes on cocos2d.podspec/
    end
  end
end
