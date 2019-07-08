require File.expand_path('../spec_helper', __FILE__)

module Pod
  describe Version do
    describe 'In general' do
      it 'initializes from a string' do
        version = Version.new('1.2.3')
        version.version.should == '1.2.3'
      end

      it 'initializes from a frozen string' do
        version = Version.new('1.2.3'.freeze)
        version.version.should == '1.2.3'
      end

      it 'serializes to a string' do
        version = Version.new('1.2.3')
        version.to_s.should == '1.2.3'
      end

      it 'identifies release versions' do
        version = Version.new('1.0.0')
        version.should.not.be.prerelease
      end

      it 'matches Semantic Version pre-release versions' do
        version = Version.new('1.0.0a1')
        version.should.be.prerelease
        version = Version.new('1.0.0-alpha')
        version.should.be.prerelease
        version = Version.new('1.0.0-alpha.1')
        version.should.be.prerelease
        version = Version.new('1.0.0-0.3.7')
        version.should.be.prerelease
        version = Version.new('1.0.0-x.7.z.92')
        version.should.be.prerelease
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Semantic Versioning' do
      it 'reports a version as semantic' do
        Version.new('1.9.0').should.be.semantic
        Version.new('1.10.0').should.be.semantic
      end

      it 'leniently reports version with two segments version a semantic' do
        Version.new('1.0').should.be.semantic
      end

      it 'leniently reports version with one segment version a semantic' do
        Version.new('1').should.be.semantic
      end

      it 'reports a pre-release version as semantic' do
        Version.new('1.0.0-alpha').should.be.semantic
        Version.new('1.0.0-alpha.1').should.be.semantic
        Version.new('1.0.0-0.3.7').should.be.semantic
        Version.new('1.0.0-x.7.z.92').should.be.semantic
      end

      it 'reports a version with metadata as semantic' do
        # Examples from http://semver.org/#spec-item-10
        Version.new('1.0.0+5').should.be.semantic
        Version.new('1.0.0+5114f85').should.be.semantic
        Version.new('1.0.0-alpha+exp.sha.5114f85').should.be.semantic
      end

      it 'reports version with more than 3 segments not separated by a dash as non semantic' do
        Version.new('1.0.2.3').should.not.be.semantic
      end

      it 'reports version with a dash without the X.Y.Z format as non semantic' do
        Version.new('1.0-alpha').should.not.be.semantic
      end

      it 'returns the major identifier' do
        Version.new('1.9.0').major.should == 1
        Version.new('1.0.0-alpha').major.should == 1
        Version.new('1.alpha').major.should == 1
      end

      it 'returns the minor identifier' do
        Version.new('1.9.0').minor.should == 9
        Version.new('1.0.0-alpha').minor.should == 0
        Version.new('1').minor.should == 0
        Version.new('1.alpha').minor.should == 0
      end

      it 'returns the patch identifier' do
        Version.new('1.9.0').patch.should == 0
        Version.new('1.0.1-alpha').patch.should == 1
        Version.new('1').patch.should == 0
        Version.new('1.alpha').patch.should == 0
        Version.new('1.alpha.2').patch.should == 0
      end

      it 'correctly makes basic version comparisons' do
        Version.new('1.0.0').should.be < Version.new('2.0.0')
        Version.new('1.0.0').should.be < Version.new('1.0.1')
        Version.new('1.0.0').should.be < Version.new('1.1.0')
        Version.new('1.1.0').should.be < Version.new('1.1.1')
      end

      it 'correctly ignores metadata in comparisons' do
        Version.new('1.0.0+fff').should == Version.new('1.0.0')
        Version.new('1.0.0+fff').should == Version.new('1.0.0+000')
        Version.new('1.0.0-beta.1+fff').should == Version.new('1.0.0-beta.1+000')
        Version.new('1.1.0+fff').should.be < Version.new('1.1.1+fff')
      end

      it 'ignores missing numeric identifiers while comparing' do
        Version.new('1.9.0-alpha').should.be < Version.new('1.9-beta')
        Version.new('2.0.0-beta').should.be < Version.new('2.0-rc')
        Version.new('2.0.0.0.0.0.1-beta').should.be > Version.new('2.0-rc')
      end

      it 'tie-breaks between semantically equal versions' do
        Version.new('1').should.be < Version.new('1.0')
        Version.new('1.0').should.be < Version.new('1.0.0')
        Version.new('1.0-alpha').should.be < Version.new('1.0.0-alpha')
        Version.new('1.1.1.1-alpha').should.be < Version.new('1.1.1.1.0-alpha')
      end

      it 'Follows semver when comparing between pre-release versions' do
        # Example from section 11 on semver.org
        Version.new('1.0.0-alpha').should.be < Version.new('1.0.0-alpha.1')
        Version.new('1.0.0-alpha.1').should.be < Version.new('1.0.0-alpha.beta')
        Version.new('1.0.0-alpha.beta').should.be < Version.new('1.0.0-beta')
        Version.new('1.0.0-beta').should.be < Version.new('1.0.0-beta.2')
        Version.new('1.0.0-beta.2').should.be < Version.new('1.0.0-beta.11')
        Version.new('1.0.0-beta.11').should.be < Version.new('1.0.0-rc.1')
        Version.new('1.0.0-rc.1').should.be < Version.new('1.0.0')

        Version.new('1.0.0-beta+fff').should == Version.new('1.0.0-beta+000')

        # Example from CocoaPods/CocoaPods#5718
        Version.new('1.0-beta.8').should.be < Version.new('1.0-beta.8a')
      end
    end

    #-------------------------------------------------------------------------#
  end
end
