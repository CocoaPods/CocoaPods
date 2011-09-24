require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Resolver" do
  before do
    fixture('spec-repos/master') # ensure the archive is unpacked
    config.repos_dir = fixture('spec-repos')
  end

  after do
    config.repos_dir = SpecHelper.tmp_repos_path
  end

  it "returns all sets needed for the dependency" do
    sets = []
    sets << Pod::Spec::Set.by_pod_dir(fixture('spec-repos/master/Reachability'))
    sets << Pod::Spec::Set.by_pod_dir(fixture('spec-repos/master/ASIHTTPRequest'))
    sets << Pod::Spec::Set.by_pod_dir(fixture('spec-repos/master/ASIWebPageRequest'))
    resolver = Pod::Resolver.new(Pod::Spec.new { |s| s.dependency 'ASIWebPageRequest' })
    resolver.resolve.sort_by(&:name).should == sets.sort_by(&:name)
  end
end

