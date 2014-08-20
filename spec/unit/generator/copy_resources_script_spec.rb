require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::CopyResourcesScript do

    it 'returns the copy resources script' do
      resources = ['path/to/resource.png']
      generator = Pod::Generator::CopyResourcesScript.new(resources, Platform.new(:ios, '6.0'))
      generator.send(:script).should.include 'path/to/resource.png'
      generator.send(:script).should.include 'storyboard'
    end

    it 'instructs ibtool to use the --reference-external-strings-file if set to do so' do
      resources = ['path/to/resource.png']
      generator_1 = Pod::Generator::CopyResourcesScript.new(resources, Platform.new(:ios, '4.0'))
      generator_2 = Pod::Generator::CopyResourcesScript.new(resources, Platform.new(:ios, '6.0'))

      generator_1.send(:script).should.not.include '--reference-external-strings-file'
      generator_2.send(:script).should.include '--reference-external-strings-file'
    end

  end
end
