require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Installer" do
  before do
    config.repos_dir = fixture('spec-repos/master')
    @spec = Pod::Spec.new do
      dependency 'SSZipArchive'
    end
  end

  after do
    config.repos_dir = SpecHelper.tmp_repos_path
  end

  it "" do
    
  end
end
