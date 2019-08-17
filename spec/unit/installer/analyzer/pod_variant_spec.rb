require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Analyzer
      describe PodVariant do
        before do
          @specs = [stub('Spec'), stub('Spec/Foo')]
          @testspecs = [stub('Spec/Tests')]
          @appspecs = [stub('Spec/App')]
          @platform = Platform.ios
          @type = BuildType.dynamic_framework
        end

        it 'can be initialized with specs and platform' do
          variant = PodVariant.new(@specs, [], [], @platform)
          variant.specs.should == @specs
          variant.platform.should == @platform
          variant.build_type.should == BuildType.static_library
        end

        it 'can be initialized with specs, platform and whether it requires frameworks' do
          variant = PodVariant.new(@specs, [], [], @platform, @type)
          variant.specs.should == @specs
          variant.platform.should == @platform
          variant.build_type.should == @type
        end

        it 'can return the root spec' do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          variant = PodVariant.new([spec], [], [], Platform.ios)
          variant.root_spec.should == spec
        end

        it 'can be compared for equality with another variant with the same specs, platform, and whether it requires frameworks' do
          spec = PodVariant.new(@specs, [], [], @platform, false)
          spec.should == PodVariant.new(@specs, [], [], @platform, false)
          spec.should.not == PodVariant.new([@specs.first], [], [], @platform)
          spec.should.not == PodVariant.new(@specs, [], [], Platform.osx, false)
          spec.should.not == PodVariant.new(@specs, [], [], @platform, true)
        end

        it 'can be used as hash keys' do
          k0 = PodVariant.new(@specs, [], [], @platform, false)
          v0 = stub('Value at index 0')
          k1 = PodVariant.new(@specs, [], [], @platform, true)
          v1 = stub('Value at index 1')
          hash = { k0 => v0, k1 => v1 }
          hash[k0].should == v0
          hash[k1].should == v1
        end

        it 'does not use testspecs for equality' do
          k0 = PodVariant.new(@specs, @testspecs, [], @platform, false)
          k1 = PodVariant.new(@specs, [], [], @platform, false)
          k0.should == k1
        end

        it 'does not use appspecs for equality' do
          k0 = PodVariant.new(@specs, [], @appspecs, @platform, false)
          k1 = PodVariant.new(@specs, [], [], @platform, false)
          k0.should == k1
        end

        it 'does not use testspecs or appspecs for equality' do
          k0 = PodVariant.new(@specs, @testspecs, [], @platform, false)
          k1 = PodVariant.new(@specs, [], @appspecs, @platform, false)
          k0.should == k1
        end
      end
    end
  end
end
