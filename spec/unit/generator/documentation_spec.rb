require File.expand_path('../../../spec_helper', __FILE__)

describe Pod::Generator::Documentation do
  before do
    @sandbox = temporary_sandbox
    @pod = Pod::LocalPod.new(fixture_spec('banana-lib/BananaLib.podspec'), @sandbox)
    copy_fixture_to_pod('banana-lib', @pod)
    @doc_installer = Pod::Generator::Documentation.new(@pod)
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
      # TODO We need to either make this a hash so that options can be merged
      # or not use any defaults in case an options are specified.
      '--project-company', 'Banana Corp',
      '--company-id', 'com.banana'
    ]
  end

  if Pod::Generator::Documentation.appledoc_installed?
    before do
      @doc_installer.generate
    end

    after do
      @sandbox.implode
    end

    it 'creates the html' do
      File.directory?(@sandbox.root + "Documentation/BananaLib/html").should.be.true
      index = (@sandbox.root + 'Documentation/BananaLib/html/index.html').read
      index.should.include?('BananaObj')
      index = (@sandbox.root + 'Documentation/BananaLib/html/Classes/BananaObj.html').read
      index.should.include?('Bananas are cool')
    end
  else
    puts "[!] Skipping documentation generation specs, because appledoc can't be found."
  end
end

