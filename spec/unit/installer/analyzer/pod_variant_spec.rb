require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe PodVariant = Installer::Analyzer::PodVariant do
    before do
      @specs = [stub('Spec'), stub('Spec/Foo')]
      @platform = Platform.ios
    end

    it 'can be initialized with specs and platform' do
      variant = PodVariant.new(@specs, @platform)
      variant.specs.should == @specs
      variant.platform.should == @platform
      variant.requires_frameworks.should == false
      variant.swift_version.should.nil?
    end

    it 'can be initialized with specs, platform and whether it requires frameworks' do
      variant = PodVariant.new(@specs, @platform, true)
      variant.specs.should == @specs
      variant.platform.should == @platform
      variant.requires_frameworks.should == true
      variant.swift_version.should.nil?
    end

    it 'can be initialized with specs, platform, whether it requires frameworks, and a Swift version' do
      variant = PodVariant.new(@specs, @platform, true, '2.3')
      variant.specs.should == @specs
      variant.platform.should == @platform
      variant.requires_frameworks.should == true
      variant.swift_version.should == '2.3'
    end

    it 'can return the root spec' do
      spec = fixture_spec('banana-lib/BananaLib.podspec')
      variant = PodVariant.new([spec], Platform.ios)
      variant.root_spec.should == spec
    end

    it 'can be compared for equality with another variant with the same specs, platform, value for whether it requires frameworks and Swift version' do
      spec = PodVariant.new(@specs, @platform, false, '2.3')
      spec.should == PodVariant.new(@specs, @platform, false, '2.3')
      spec.should.not == PodVariant.new(@specs, @platform, false, '3.0')
      spec.should.not == PodVariant.new([@specs.first], @platform, false)
      spec.should.not == PodVariant.new(@specs, Platform.osx, false, '2.3')
      spec.should.not == PodVariant.new(@specs, @platform, true)
    end

    it 'can be used as hash keys' do
      k0 = PodVariant.new(@specs, @platform, false)
      v0 = stub('Value at index 0')
      k1 = PodVariant.new(@specs, @platform, true)
      v1 = stub('Value at index 1')
      hash = { k0 => v0, k1 => v1 }
      hash[k0].should == v0
      hash[k1].should == v1
    end
  end
end
