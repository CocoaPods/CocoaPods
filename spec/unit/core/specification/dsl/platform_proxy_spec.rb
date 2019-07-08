require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Specification::DSL::PlatformProxy do
    before do
      @spec =  Spec.new
      @proxy = Specification::DSL::PlatformProxy.new(@spec, :ios)
    end

    it 'forwards multi-platform attributes to the specification' do
      attrs = Specification::DSL.attributes.values.select(&:multi_platform?)
      attrs.each do |attr|
        @spec.expects(:store_attribute).with(attr.name, 'a_value', :ios).once
        @proxy.send(attr.writer_name, 'a_value')
      end
    end

    it 'supports the singular form of attributes' do
      attrs = Specification::DSL.attributes.values.select(&:multi_platform?)
      singular_attrs = attrs.select(&:writer_singular_form)
      singular_attrs.each do |attr|
        @spec.expects(:store_attribute).with(attr.name, 'a_value', :ios).once
        @proxy.send(attr.writer_singular_form, 'a_value')
      end
    end

    it 'does not respond to non multiplatform attributes' do
      attrs = Specification::DSL.attributes.values.select { |a| !a.multi_platform? }
      attrs.each do |attr|
        e = lambda { @proxy.send(attr.writer_name, 'a_value') }.should.raise NoMethodError
        e.message.should.include "`#{attr.name}` cannot be set per-platform"
      end
    end

    it 'does not respond to platform=' do
      lambda { @proxy.platform = :ios, '9.0' }.should.raise NoMethodError
    end

    it 'allows to specify a dependency' do
      @proxy.dependency('A-pod', '~> 1.0')
      @spec.attributes_hash['ios']['dependencies'].should == {
        'A-pod' => ['~> 1.0'],
      }
    end

    it 'allows to specify a dependency without version requirements' do
      @proxy.dependency('A-pod')
      @spec.attributes_hash['ios']['dependencies'].should == {
        'A-pod' => [],
      }
    end

    it 'allows to specify a dependency with multiple version requirements' do
      @proxy.dependency('A-pod', '~> 1.0', '< 2.0')
      @spec.attributes_hash['ios']['dependencies'].should == {
        'A-pod' => ['~> 1.0', '< 2.0'],
      }
    end

    it 'allows to declare the deployment target' do
      @proxy.deployment_target = '6.0'
      @spec.attributes_hash['platforms']['ios'].should == '6.0'
    end
  end
end
