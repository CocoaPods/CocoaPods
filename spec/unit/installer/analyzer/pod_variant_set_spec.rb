require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe PodVariantSet = Installer::Analyzer::PodVariantSet do
    describe '#scope_suffixes' do
      before do
        @root_spec = fixture_spec('matryoshka/matryoshka.podspec')
        @default_subspec = @root_spec.subspec_by_name('matryoshka/Outer')
        @foo_subspec = @root_spec.subspec_by_name('matryoshka/Foo')
        @bar_subspec = @root_spec.subspec_by_name('matryoshka/Bar')
      end

      PodVariant = Pod::Installer::Analyzer::PodVariant.freeze

      it 'returns an empty scope if there is only one variant' do
        variants = PodVariantSet.new([PodVariant.new([@root_spec], Platform.ios)])
        variants.scope_suffixes.values.should == [nil]
      end

      it 'returns scopes by built types if they qualify' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec], Platform.ios, true),
          PodVariant.new([@root_spec], Platform.ios, false),
        ])
        variants.scope_suffixes.values.should == %w(framework library)
      end

      it 'returns scopes by platform names if they qualify' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec], Platform.ios),
          PodVariant.new([@root_spec], Platform.osx),
        ])
        variants.scope_suffixes.values.should == %w(iOS OSX)
      end

      it 'returns scopes by versioned platform names if they qualify' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec], Platform.ios),
          PodVariant.new([@root_spec], Platform.new(:ios, '7.0')),
        ])
        variants.scope_suffixes.values.should == ['iOS', 'iOS7.0']
      end

      it 'returns scopes by subspec names if they qualify' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec, @default_subspec], Platform.ios),
          PodVariant.new([@root_spec, @default_subspec, @foo_subspec], Platform.ios),
          PodVariant.new([@root_spec, @default_subspec, @bar_subspec], Platform.ios),
        ])
        variants.scope_suffixes.values.should == [nil, 'Foo', 'Bar']
      end

      it 'returns scopes by subspec names if they qualify and handle partial root spec presence well' do
        variants = PodVariantSet.new([
          PodVariant.new([@foo_subspec], Platform.ios),
          PodVariant.new([@root_spec, @bar_subspec], Platform.ios),
        ])
        variants.scope_suffixes.values.should == ['Foo', 'Bar-root']
      end

      it 'returns scopes by platform names and subspec names if they qualify' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec], Platform.ios),
          PodVariant.new([@root_spec], Platform.osx),
          PodVariant.new([@root_spec, @foo_subspec], Platform.ios),
          PodVariant.new([@root_spec, @bar_subspec], Platform.osx),
        ])
        variants.scope_suffixes.values.should == [
          'iOS',
          'OSX',
          'Foo',
          'Bar',
        ]
      end

      it 'returns scopes by versioned platform names and subspec names if they qualify' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec], Platform.new(:ios, '7.0')),
          PodVariant.new([@root_spec], Platform.ios),
          PodVariant.new([@root_spec], Platform.osx),
          PodVariant.new([@root_spec, @bar_subspec], Platform.osx),
        ])
        variants.scope_suffixes.values.should == [
          'iOS7.0',
          'iOS',
          'OSX',
          'Bar',
        ]
      end

      it 'returns scopes by built types, versioned platform names and subspec names' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec], Platform.new(:ios, '7.0')),
          PodVariant.new([@root_spec], Platform.ios),
          PodVariant.new([@root_spec], Platform.osx, true),
          PodVariant.new([@root_spec, @foo_subspec], Platform.ios),
          PodVariant.new([@root_spec, @foo_subspec], Platform.osx, true),
        ])
        variants.scope_suffixes.values.should == [
          'library-iOS7.0',
          'library-iOS',
          'framework',
          'Foo-library',
          'Foo-framework',
        ]
      end
    end
  end
end
