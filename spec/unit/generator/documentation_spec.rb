require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::Documentation do
    before do
      sandbox = config.sandbox
      spec = fixture_spec('banana-lib/BananaLib.podspec')
      root = fixture('banana-lib')
      path_list = Sandbox::PathList.new(root)
      @doc_installer = Generator::Documentation.new(sandbox, spec, path_list)
    end

    it 'returns the Pod documentation header files' do
      @doc_installer.public_headers.sort.should == %w[ Classes/Banana.h ].sort
    end

    it 'returns an empty array in case there are no appledoc options specified' do
      @doc_installer.specification.stubs(:documentation).returns({})
      @doc_installer.spec_appledoc_options.should == []
    end

    it 'returns the Pod documentation options' do
      expected = [
        '--project-name', 'BananaLib 1.0',
        '--docset-desc', 'Chunky bananas!',
        '--project-company', 'Banana Corp and Monkey Boy',
        '--docset-copyright', 'Banana Corp and Monkey Boy',
        '--company-id', 'org.cocoapods.bananalib',
        '--ignore', '.m',
        '--keep-undocumented-objects',
        '--keep-undocumented-members',
        '--keep-intermediate-files',
        '--exit-threshold', '2',
        '--index-desc', 'README',
        '--project-company', 'Banana Corp',
        '--company-id', 'com.banana'
      ]
      options = @doc_installer.appledoc_options
      expected.each do |expected_option|
        options.should.include?(expected_option)
      end
    end

    it "returns the command line arguments to pass to the appledoc tool" do
      arguments = @doc_installer.apple_doc_command_line_arguments(install_docset=false)
      arguments.should.include?("--project-name 'BananaLib 1.0' ")
      arguments.should.include?(" --docset-desc 'Chunky bananas!' ")
      arguments.should.include?(" --project-company 'Banana Corp and Monkey Boy' ")
      arguments.should.include?(" --docset-copyright 'Banana Corp and Monkey Boy' ")
      arguments.should.include?(" --company-id org.cocoapods.bananalib ")
      arguments.should.include?(" --ignore .m ")
      arguments.should.include?(" --keep-undocumented-objects ")
      arguments.should.include?(" --keep-undocumented-members ")
      arguments.should.include?(" --keep-intermediate-files ")
      arguments.should.include?(" --exit-threshold 2 ")
      arguments.should.include?(" --index-desc README ")
      arguments.should.include?(" --project-company 'Banana Corp' ")
      arguments.should.include?(" --company-id com.banana ")
      # arguments.should.include?(" --output tmp/Pods/Documentation/BananaLib ")
      arguments.should.include?(" --no-create-docset Classes/Banana.h")
      arguments.should.include?(" Classes/Banana.h")
    end

    #-------------------------------------------------------------------------#

    if !`which appledoc`.strip.empty?

      describe "Appledoc integration" do
        before do
          @doc_installer.generate(false)
        end

        it 'creates the html' do
          docs_path = config.sandbox.root + "Documentation/BananaLib/html"
          docs_path.should.exist
          (docs_path + 'index.html').read.should.include?('BananaObj')
          (docs_path + 'Classes/BananaObj.html').read.should.include?('Bananas are cool')
        end
      end

    else
      puts "[!] Skipping documentation generation specs, because appledoc can't be found."
    end
  end

end
