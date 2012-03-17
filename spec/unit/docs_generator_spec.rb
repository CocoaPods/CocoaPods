require File.expand_path('../../spec_helper', __FILE__)


describe Pod::DocsGenerator do

  before do
    @sandbox = temporary_sandbox
    @pod = Pod::LocalPod.new(fixture_spec('banana-lib/BananaLib.podspec'), @sandbox)
    copy_fixture_to_pod('banana-lib', @pod)
    @doc_installer = Pod::DocsGenerator.new(@pod)
    @doc_installer.generate
  end

  it 'returns reads correctly the Pod documentation' do
    @doc_installer.options.should == {
    :html => 'http://banana-corp.local/banana-lib/docs.html',
    :appledoc => [
       '--project-company', 'Banana Corp',
       '--company-id', 'com.banana',
    ]
  }
  end

  it 'returns the Pod documentation documentation files' do
    @doc_installer.files.sort.should == [
      @pod.root + "Classes/Banana.m",
      @pod.root + "Classes/Banana.h",
    ].sort
  end

  it 'returns the Pod documentation options' do
    @doc_installer.generate_appledoc_options.should == [
      '--project-name', 'BananaLib (1.0)',
      '--docset-desc', 'Full of chunky bananas.',
      '--project-company', 'Monkey Boy, Banana Corp',
      '--docset-copyright', 'Monkey Boy, Banana Corp',
      '--company-id', 'org.cocoapods',
      '--ignore', '.m',
      '--keep-undocumented-objects',
      '--keep-undocumented-members',
      '--index-desc', 'README',
      '--project-company', 'Banana Corp',
      '--company-id', 'com.banana'
    ]
  end

  it 'it creates the documenation directory' do
    File.directory?(@sandbox.root + "Documentation").should.be.true
  end

  it 'it creates the html' do
    File.directory?(@sandbox.root + "Documentation/BananaLib/html").should.be.true
    index = (@sandbox.root + 'Documentation/BananaLib/html/index.html').read
    index.should.include?('BananaObj')
    index = (@sandbox.root + 'Documentation/BananaLib/html/Classes/BananaObj.html').read
    index.should.include?('Bananas are cool')
  end
end

