require File.expand_path('../../../spec_helper', __FILE__)

# TODO: The Copy Resources Script is soon to be deprecated with PR #3263
#       We probably will remove all those family of specs
#
module Pod
  describe Generator::CopyResourcesScript do
    xit 'returns the copy resources script' do
      resources = { 'Release' => ['path/to/resource.png'] }
      generator = Pod::Generator::CopyResourcesScript.new(resources, Platform.new(:ios, '6.0'))
      generator.send(:script).should.include 'path/to/resource.png'
      generator.send(:script).should.include 'storyboard'
    end

    xit 'instructs ibtool to use the --reference-external-strings-file if set to do so' do
      resources = { 'Release' => ['path/to/resource.png'] }
      generator_1 = Pod::Generator::CopyResourcesScript.new(resources, Platform.new(:ios, '4.0'))
      generator_2 = Pod::Generator::CopyResourcesScript.new(resources, Platform.new(:ios, '6.0'))

      generator_1.send(:script).should.not.include '--reference-external-strings-file'
      generator_2.send(:script).should.include '--reference-external-strings-file'
    end

    xit 'adds configuration dependent resources with a call wrapped in an if statement' do
      resources = { 'Debug' => %w(Lookout.framework) }
      generator = Pod::Generator::CopyResourcesScript.new(resources, Platform.new(:ios, '6.0'))
      script = generator.send(:script)
      script.should.include <<-eos.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_resource "Lookout.framework"
        fi
      eos
    end

    xit 'adds resource bundles with a call wrapped in an if statement' do
      resources = { 'Debug' => %w(${BUILT_PRODUCTS_DIR}/Resources.bundle) }
      generator = Pod::Generator::CopyResourcesScript.new(resources, Platform.new(:ios, '6.0'))
      script = generator.send(:script)
      script.should.include <<-eos.strip_heredoc
        if [[ "$CONFIGURATION" == "Debug" ]]; then
          install_resource "${BUILT_PRODUCTS_DIR}/Resources.bundle"
        fi
      eos
    end
  end
end
