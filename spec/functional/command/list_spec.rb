require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::List do
    extend SpecHelper::TemporaryRepos

    it "lists the known pods" do
      out = run_command('list')
      [ /ZBarSDK/,
        /TouchJSON/,
        /SDURLCache/,
        /MagicalRecord/,
        /A2DynamicDelegate/,
        /\d+ pods were found/
      ].each { |regex| out.should =~ regex }
    end

    it "lists the new pods" do
      Time.stubs(:now).returns(Time.mktime(2012,2,3))
      out = run_command('list', 'new')
      [ 'iCarousel',
        'libPusher',
        'SSCheckBoxView',
        'KKPasscodeLock',
        'SOCKit',
        'FileMD5Hash',
        'cocoa-oauth',
        'iRate'
      ].each {|s| out.should.include s }
    end
  end
end

