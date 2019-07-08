require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Source::Metadata do
    before do
      @metadata_hash = {
        'min' => '0.33.1',
        'max' => '1.9.9',
        'last' => CORE_VERSION,
        'prefix_lengths' => [1, 1, 1],
        'last_compatible_versions' => ['0.22.0', '0.11.0', '0.20.5'],
      }
      @metadata = Source::Metadata.new(@metadata_hash)
    end

    describe '#initialize' do
      it 'sets the minimum_cocoapods_version' do
        @metadata.minimum_cocoapods_version.should == Version.new('0.33.1')
      end

      it 'sets the maximum_cocoapods_version' do
        @metadata.maximum_cocoapods_version.should == Version.new('1.9.9')
      end

      it 'sets the prefix_lengths' do
        @metadata.prefix_lengths.should == [1, 1, 1]
      end

      it 'sets the latest_cocoapods_version' do
        @metadata.latest_cocoapods_version.should == Version.new(CORE_VERSION)
      end

      it 'sets the last_compatible_versions' do
        @metadata.last_compatible_versions.should == [
          Pod::Version.new('0.11.0'),
          Pod::Version.new('0.20.5'),
          Pod::Version.new('0.22.0'),
        ]
      end
    end

    describe '#path_fragment' do
      it 'returns correct shard in array form' do
        @metadata.path_fragment('DfPodTest').should == %w(2 2 2 DfPodTest)
      end

      it 'handles one-character names' do
        @metadata.path_fragment('T').should == %w(b 9 e T)
      end

      it 'handles non-ascii names' do
        @metadata.path_fragment('🔒').should == %w(c 5 1 🔒)
      end
    end

    describe '#last_compatible_version' do
      it 'returns the last compatible version if available' do
        metadata_hash = {
          'min' => '1.9.0',
          'max' => '2.0.0',
          'last_compatible_versions' => %w(1.0 1.4 2.0),
        }
        metadata = Source::Metadata.new(metadata_hash)
        result = metadata.last_compatible_version(Version.new('1.5.0'))
        result.should == Pod::Version.new('1.4.0')
      end

      it 'raises when unable to find a compatible version' do
        metadata_hash = {
          'min' => '2.0.0',
          'max' => '2.0.0',
        }
        metadata = Source::Metadata.new(metadata_hash)
        should.raise Pod::Informative do
          metadata.last_compatible_version(Version.new('1.5.0'))
        end.message.should.match /Unable to find compatible version/
      end
    end

    describe '#compatible?' do
      it 'returns whether a repository is compatible' do
        @metadata = Source::Metadata.new('min' => '0.0.1')
        @metadata.compatible?('1.0.0').should.be.true

        @metadata = Source::Metadata.new('max' => '999.0')
        @metadata.compatible?('1.0.0').should.be.true

        @metadata = Source::Metadata.new('min' => '999.0')
        @metadata.compatible?('1.0.0').should.be.false

        @metadata = Source::Metadata.new('max' => '0.0.1')
        @metadata.compatible?('1.0.0').should.be.false
      end
    end

    describe '#to_hash' do
      it 'returns a hash representation of the metadata' do
        @metadata.to_hash.should == {
          'min' => '0.33.1',
          'max' => '1.9.9',
          'last' => CORE_VERSION,
          'prefix_lengths' => [1, 1, 1],
          'last_compatible_versions' => ['0.11.0', '0.20.5', '0.22.0'],
        }
      end

      it 'excludes missing properties' do
        @metadata = Source::Metadata.new('min' => '999.0')
        @metadata.to_hash.should == {
          'min' => '999.0',
        }
      end
    end
  end
end
