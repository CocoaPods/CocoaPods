require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe PodVariantSet = Installer::Analyzer::PodVariantSet do
    describe '#scope_suffixes' do
      before do
        @root_spec = stub(:name => 'Spec', :root? => true)
      end

      PodVariant = Pod::Installer::Analyzer::PodVariant.freeze

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
        shared_subspec = stub(:name => 'Spec/Shared', :root? => false)
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec, shared_subspec], Platform.ios),
          PodVariant.new([@root_spec, shared_subspec, stub(:name => 'Spec/Foo', :root? => false)], Platform.ios),
          PodVariant.new([@root_spec, shared_subspec, stub(:name => 'Spec/Bar', :root? => false)], Platform.ios),
        ])
        variants.scope_suffixes.values.should == [nil, 'Foo', 'Bar']
      end

      it 'returns scopes by subspec names if they qualify and handle partial root spec presence well' do
        variants = PodVariantSet.new([
          PodVariant.new([stub(:name => 'Spec/Foo', :root? => false)], Platform.ios),
          PodVariant.new([@root_spec, stub(:name => 'Spec/Bar', :root? => false)], Platform.ios),
        ])
        variants.scope_suffixes.values.should == ['Foo', 'Bar-root']
      end

      it 'returns scopes by platform names and subspec names if they qualify' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec], Platform.ios),
          PodVariant.new([@root_spec, stub(:name => 'Spec/Foo', :root? => false)], Platform.ios),
          PodVariant.new([@root_spec], Platform.osx),
          PodVariant.new([@root_spec, stub(:name => 'Spec/Bar', :root? => false)], Platform.osx),
        ])
        variants.scope_suffixes.values.should == [
          'iOS',
          'iOS-Foo',
          'OSX',
          'OSX-Bar',
        ]
      end

      it 'returns scopes by versioned platform names and subspec names if they qualify' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec], Platform.new(:ios, '7.0')),
          PodVariant.new([@root_spec, stub(:name => 'Spec/Foo', :root? => false)], Platform.ios),
          PodVariant.new([@root_spec], Platform.osx),
          PodVariant.new([@root_spec, stub(:name => 'Spec/Bar', :root? => false)], Platform.osx),
        ])
        variants.scope_suffixes.values.should == [
          'iOS7.0',
          'iOS',
          'OSX',
          'OSX-Bar',
        ]
      end

      it 'returns scopes by built types, versioned platform names and subspec names' do
        variants = PodVariantSet.new([
          PodVariant.new([@root_spec], Platform.new(:ios, '7.0')),
          PodVariant.new([@root_spec], Platform.ios),
          PodVariant.new([@root_spec], Platform.osx, true),
          PodVariant.new([@root_spec, stub(:name => 'Spec/Foo', :root? => false)], Platform.osx, true),
        ])
        variants.scope_suffixes.values.should == [
          'library-iOS7.0',
          'library-iOS',
          'framework',
          'framework-Foo',
        ]
      end
    end
  end
end
