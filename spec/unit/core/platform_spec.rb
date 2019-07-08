require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Platform do
    describe 'In general' do
      it 'returns a new Platform instance' do
        Platform.ios.should == Platform.new(:ios)
        Platform.osx.should == Platform.new(:osx)
        Platform.tvos.should == Platform.new(:tvos)
        Platform.watchos.should == Platform.new(:watchos)
        Platform.all.should.include? Platform.new(:ios)
        Platform.all.should.include? Platform.new(:osx)
        Platform.all.should.include? Platform.new(:tvos)
        Platform.all.should.include? Platform.new(:watchos)
      end

      it 'can be initialized from another platform' do
        platform = Platform.new(:ios)
        new = Platform.new(platform)
        new.should == platform
      end

      before do
        @platform = Platform.ios
      end

      it 'exposes its symbolic name' do
        @platform.name.should == :ios
      end

      it 'can be initialized with a string symbolic name' do
        Platform.new('ios')
        @platform.name.should == :ios
      end

      it 'exposes its name as string' do
        Platform.ios.string_name.should == 'iOS'
        Platform.osx.string_name.should == 'macOS'
        Platform.tvos.string_name.should == 'tvOS'
        Platform.watchos.string_name.should == 'watchOS'
      end

      it 'exposes a safe variant of its name as string' do
        Platform.ios.safe_string_name.should == 'iOS'
        Platform.osx.safe_string_name.should == 'macOS'
        Platform.tvos.safe_string_name.should == 'tvOS'
        Platform.watchos.safe_string_name.should == 'watchOS'
      end

      it 'can be compared for equality with another platform with the same symbolic name' do
        @platform.should == Platform.new(:ios)
      end

      it 'can be compared for equality with another platform with the same symbolic name and the same deployment target' do
        @platform.should.not == Platform.new(:ios, '4.0')
        Platform.new(:ios, '4.0').should == Platform.new(:ios, '4.0')
      end

      it 'can be compared for equality with a matching symbolic name (backwards compatibility reasons)' do
        @platform.should == :ios
      end

      it 'presents an accurate string representation' do
        @platform.to_s.should == 'iOS'
        Platform.new(:osx).to_s.should == 'macOS'
        Platform.new(:watchos).to_s.should == 'watchOS'
        Platform.new(:tvos).to_s.should == 'tvOS'
        Platform.new(:ios, '5.0.0').to_s.should == 'iOS 5.0.0'
        Platform.new(:osx, '10.7').to_s.should == 'macOS 10.7'
        Platform.new(:watchos, '2.0').to_s.should == 'watchOS 2.0'
        Platform.new(:tvos, '9.0').to_s.should == 'tvOS 9.0'
      end

      it 'uses its name as its symbold version' do
        @platform.to_sym.should == :ios
      end

      it 'allows to specify the deployment target on initialization' do
        p = Platform.new(:ios, '4.0.0')
        p.deployment_target.should == Version.new('4.0.0')
      end

      it 'allows to specify the deployment target in a hash on initialization (backwards compatibility from 0.6)' do
        p = Platform.new(:ios,  :deployment_target => '4.0.0')
        p.deployment_target.should == Version.new('4.0.0')
      end

      it 'can be sorted by name' do
        p_1 = Platform.new(:ios, '4.0')
        p_2 = Platform.new(:osx, '10.6')
        (p_1 <=> p_2).should == -1
        (p_1 <=> p_1).should == 0
        (p_2 <=> p_1).should == 1
      end

      it 'can be sorted by deployment_target' do
        p_1 = Platform.new(:ios, '4.0')
        p_2 = Platform.new(:ios, '6.0')
        (p_1 <=> p_2).should == -1
        (p_1 <=> p_1).should == 0
        (p_2 <=> p_1).should == 1
      end

      it 'returns whether it requires legacy iOS architectures' do
        Platform.new(:ios, '4.0').requires_legacy_ios_archs?.should.be.true
        Platform.new(:ios, '5.0').requires_legacy_ios_archs?.should.be.false
        Platform.new(:watchos, '2.0').requires_legacy_ios_archs?.should.be.false
        Platform.new(:tvos, '9.0').requires_legacy_ios_archs?.should.be.false
      end

      it 'is usable as hash keys' do
        ios   = Platform.new(:ios)
        osx   = Platform.new(:osx)
        ios6  = Platform.new(:ios, '6.0')
        ios61 = Platform.new(:ios, '6.1')
        hash  = { ios => ios, osx => osx, ios6 => ios6, ios61 => ios61 }
        hash[Platform.new(:ios)].should.be.eql ios
        hash[Platform.new(:osx)].should.be.eql osx
        hash[Platform.new(:ios, '6.0')].should.be.eql ios6
        hash[Platform.new(:ios, '6.1')].should.be.eql ios61
      end

      describe '#supports_dynamic_frameworks?' do
        it 'supports dynamic frameworks on OSX' do
          Platform.osx.should.supports_dynamic_frameworks
          Platform.new(:osx, '10.7').should.supports_dynamic_frameworks
          Platform.new(:osx, '10.10').should.supports_dynamic_frameworks
        end

        it 'supports dynamic frameworks on iOS since version 8.0' do
          Platform.ios.should.not.supports_dynamic_frameworks
          Platform.new(:ios, '7.0').should.not.supports_dynamic_frameworks
          Platform.new(:ios, '8.0').should.supports_dynamic_frameworks
          Platform.new(:ios, '8.1').should.supports_dynamic_frameworks
        end

        it 'supports dynamic frameworks on watchOS' do
          Platform.watchos.should.supports_dynamic_frameworks
          Platform.new(:watchos, '2.0').should.supports_dynamic_frameworks
        end

        it 'supports dynamic frameworks on tvOS' do
          Platform.tvos.should.supports_dynamic_frameworks
          Platform.new(:tvos, '9.0').should.supports_dynamic_frameworks
        end
      end
    end

    describe 'Supporting other platforms' do
      it 'supports platforms with the same operating system' do
        p1 = Platform.new(:ios)
        p2 = Platform.new(:ios)
        p1.should.supports?(p2)

        p1 = Platform.new(:osx)
        p2 = Platform.new(:osx)
        p1.should.supports?(p2)
      end

      it 'supports a platform with a lower or equal deployment_target' do
        p1 = Platform.new(:ios, '5.0')
        p2 = Platform.new(:ios, '4.0')
        p1.should.supports?(p1)
        p1.should.supports?(p2)
        p2.should.not.supports?(p1)
      end

      it "doesn't supports a platform with a different operating system" do
        p1 = Platform.new(:ios)
        p2 = Platform.new(:osx)
        p1.should.not.supports?(p2)
      end

      it 'returns the string name of a given symbolic name' do
        Platform.string_name(:ios).should == 'iOS'
        Platform.string_name(:osx).should == 'macOS'
        Platform.string_name(:win).should == 'win'
      end
    end
  end
end
