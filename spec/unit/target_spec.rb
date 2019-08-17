require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Target do
    describe '#c99ext_identifier' do
      before do
        @target = Target.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios)
      end

      it 'should mask, but keep leading numbers' do
        @target.send(:c99ext_identifier, '123BananaLib').should == '_123BananaLib'
      end

      it 'should mask invalid chars' do
        @target.send(:c99ext_identifier, 'iOS-App BânánàLïb').should == 'iOS_App_B_n_n_L_b'
      end

      it 'has a human-readable #to_s' do
        @target.to_s.should == @target.label
      end
    end
  end
end
