require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Installer" do
  before do
    fixture('spec-repos/master') # ensure the archive is unpacked
    config.repos_dir = fixture('spec-repos')
    @spec = Pod::Spec.new do
      dependency 'JSONKit'
    end
  end

  after do
    config.repos_dir = SpecHelper.tmp_repos_path
  end
end
