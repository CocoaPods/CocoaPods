require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::Lib::Create do
    before do
      @sut = Command::Lib::Create
    end

    it 'complains if wrong parameters' do
      lambda { run_command('lib', 'create') }.should.raise CLAide::Help
    end

    it 'complains if pod name contains spaces' do
      lambda { run_command('lib', 'create', 'Pod Name With Spaces') }.should.raise CLAide::Help
    end

    it 'complains if pod name contains plusses' do
      lambda { run_command('lib', 'create', 'Pod+Name+With+Plusses') }.should.raise CLAide::Help
    end

    it 'complains if pod name begins with a period' do
      lambda { run_command('lib', 'create', '.HiddenPod') }.should.raise CLAide::Help
    end

    it 'should create a new dir for the newly created pod' do
      @sut.any_instance.stubs(:configure_template)
      url = @sut::TEMPLATE_REPO
      @sut.any_instance.expects(:git!).with(['clone', url, 'TestPod']).once
      run_command('lib', 'create', 'TestPod')
    end

    it 'configures the template after cloning it passing the name of the Pod and any other args as the argument' do
      @sut.any_instance.stubs(:clone_template)
      dir = SpecHelper.temporary_directory + 'TestPod'
      dir.mkpath
      File.stubs(:exist?).with('configure').returns(true)
      @sut.any_instance.expects(:system).with({ 'COCOAPODS_VERSION' => Pod::VERSION }, './configure', 'TestPod', 'foo').once
      run_command('lib', 'create', 'TestPod', 'foo', '--verbose')
    end

    it 'should show link to new pod guide after creation' do
      @sut.any_instance.stubs(:clone_template)
      @sut.any_instance.stubs(:configure_template)
      output = run_command('lib', 'create', 'TestPod')
      output.should.include? 'https://guides.cocoapods.org/making/making-a-cocoapod'
    end

    before do
      @sut.any_instance.stubs(:configure_template)
    end

    it 'should use the given template URL' do
      template_url = 'https://github.com/custom/template.git'
      @sut.any_instance.expects(:git!).with(['clone', template_url, 'TestPod']).once
      run_command('lib', 'create', 'TestPod', "--template-url=#{template_url}")
    end

    it 'should use the default URL if no template URL is given' do
      template_url = 'https://github.com/CocoaPods/pod-template.git'
      @sut.any_instance.expects(:git!).with(['clone', template_url, 'TestPod']).once
      run_command('lib', 'create', 'TestPod')
    end
  end
end
