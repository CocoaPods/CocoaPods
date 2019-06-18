require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe PodVariantSet = Installer::Analyzer::PodVariantSet do
    describe '#scope_suffixes' do
      before do
        @root_spec = fixture_spec('matryoshka/matryoshka.podspec')
        @default_subspec = @root_spec.subspec_by_name('matryoshka/Outer')
        @inner_subspec = @root_spec.subspec_by_name('matryoshka/Outer/Inner')
        @foo_subspec = @root_spec.subspec_by_name('matryoshka/Foo')
        @bar_subspec = @root_spec.subspec_by_name('matryoshka/Bar')
      end

      PodVariant = Pod::Installer::Analyzer::PodVariant.freeze

      it 'returns an empty scope if there is only one variant' do
        variants = PodVariantSet.new([PodVariant.new([@root_spec], [], [], Platform.ios)])
        variants.scope_suffixes.values.should == [nil]
      end

      it 'returns scopes by built types if they qualify' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec], [], [], Platform.ios, BuildType.dynamic_framework),
          PodVariant.new([@root_spec], [], [], Platform.ios),
        ])
        variants.scope_suffixes.values.should == %w(framework library)
      end

      it 'returns scopes by platform names if they qualify' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec], [], [], Platform.ios),
          PodVariant.new([@root_spec], [], [], Platform.osx),
        ])
        variants.scope_suffixes.values.should == %w(iOS macOS)
      end

      it 'returns scopes by versioned platform names if they qualify' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec], [], [], Platform.ios),
          PodVariant.new([@root_spec], [], [], Platform.new(:ios, '7.0')),
        ])
        variants.scope_suffixes.values.should == %w(iOS iOS7.0)
      end

      it 'returns scopes by subspec names if they qualify' do
        variants = PodVariantSet.new([
          PodVariant.new([@foo_subspec], [], [], Platform.ios),
          PodVariant.new([@bar_subspec], [], [], Platform.ios),
        ])
        variants.scope_suffixes.values.should == %w(Foo Bar)
      end

      it 'returns scopes by subspec names if they qualify and handle partial root spec presence well' do
        variants = PodVariantSet.new([
          PodVariant.new([@foo_subspec], [], [], Platform.ios),
          PodVariant.new([@root_spec, @bar_subspec], [], [], Platform.ios),
        ])
        variants.scope_suffixes.values.should == %w(Foo .root-Bar)
      end

      it 'allows to differentiate between an exclusive variant with a specific subspec and ' \
        'an inclusive variant with the default subspecs plus a non-default subspec' do
        variants = PodVariantSet.new([
          PodVariant.new([@foo_subspec], [], [], Platform.ios),
          PodVariant.new([@root_spec, @default_subspec, @foo_subspec], [], [], Platform.ios),
        ])
        variants.scope_suffixes.values.should == %w(Foo .default-Foo)
      end

      it 'omits default specs' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.ios),
          PodVariant.new([@root_spec, @default_subspec, @foo_subspec], [], [], Platform.ios),
          PodVariant.new([@root_spec, @default_subspec, @bar_subspec], [], [], Platform.ios),
        ])
        variants.scope_suffixes.values.should == [nil, '.default-Foo', '.default-Bar']
      end

      it 'omits common specs' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec, @default_subspec, @inner_subspec], [], [], Platform.ios),
          PodVariant.new([@root_spec, @default_subspec, @inner_subspec, @foo_subspec], [], [], Platform.ios),
          PodVariant.new([@root_spec, @default_subspec, @inner_subspec, @bar_subspec], [], [], Platform.ios),
        ])
        variants.scope_suffixes.values.should == %w(.common .common-Foo .common-Bar)
      end

      it 'returns scopes by platform names and subspec names if they qualify' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.ios),
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.osx),
          PodVariant.new([@root_spec, @default_subspec, @foo_subspec], [], [], Platform.ios),
          PodVariant.new([@root_spec, @default_subspec, @bar_subspec], [], [], Platform.osx),
        ])
        variants.scope_suffixes.values.should == %w(
          iOS
          macOS
          .default-Foo
          .default-Bar
        )
      end

      it 'hashes scopes that are longer than 50 characters' do
        @bar_subspec.name = 'matryoshka/ThisIsAReallyLongSubspecName'
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.ios),
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.osx),
          PodVariant.new([@root_spec, @default_subspec, @foo_subspec, @bar_subspec], [], [], Platform.ios),
          PodVariant.new([@root_spec, @default_subspec, @bar_subspec], [], [], Platform.osx),
        ])
        variants.scope_suffixes.values.should == %w(
          iOS
          macOS
          c4ca5113
          .default-matryoshka_ThisIsAReallyLongSubspecName
        )
      end

      it 'returns scopes by versioned platform names and subspec names if they qualify' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.new(:ios, '7.0')),
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.ios),
          PodVariant.new([@root_spec, @default_subspec, @foo_subspec], [], [], Platform.ios),
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.osx),
          PodVariant.new([@root_spec, @default_subspec, @foo_subspec], [], [], Platform.osx),
          PodVariant.new([@root_spec, @default_subspec, @bar_subspec], [], [], Platform.osx),
        ])
        variants.scope_suffixes.values.should == %w(
          iOS7.0
          iOS
          macOS
          .default-Foo-iOS
          .default-Foo-macOS
          .default-Bar
        )
      end

      it 'returns scopes by built types, versioned platform names and subspec names' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.new(:ios, '7.0')),
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.ios),
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.osx, BuildType.dynamic_framework),
          PodVariant.new([@root_spec, @default_subspec, @foo_subspec], [], [], Platform.osx, BuildType.dynamic_framework),
        ])
        variants.scope_suffixes.values.should == %w(
          library-iOS7.0
          library-iOS
          framework
          .default-Foo
        )
      end

      it 'returns scopes differentiating build types' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.ios),
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.ios, BuildType.dynamic_framework),
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.ios, BuildType.static_framework),
        ])
        variants.scope_suffixes.values.should == %w(
          library
          framework-dynamic
          framework-static
        )
      end

      it 'returns scopes based on Swift version' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.ios, BuildType.dynamic_framework, '3.2'),
          PodVariant.new([@root_spec, @default_subspec], [], [], Platform.ios, BuildType.dynamic_framework, '4.0'),
        ])
        variants.scope_suffixes.values.should == %w(
          Swift3.2
          Swift4.0
        )
      end
    end
  end
end
