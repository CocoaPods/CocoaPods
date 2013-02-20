require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::IPC do

    describe Command::IPC::Spec do

      it "converts a podspec to yaml and prints it to STDOUT" do
        out = run_command('ipc', 'spec', fixture('banana-lib/BananaLib.podspec'))
        out.should.include('---')
        out.should.match /name: BananaLib/
        out.should.match /version: .1\.0./
        out.should.match /description: Full of chunky bananas./
      end

    end

    #-------------------------------------------------------------------------#

    describe Command::IPC::List do

      it "converts a podspec to yaml and prints it to STDOUT" do
        spec = fixture_spec('banana-lib/BananaLib.podspec')
        set = Specification.new('BananaLib')
        set.stubs(:specification).returns(spec)
        SourcesManager.stubs(:all_sets).returns([set])

        out = run_command('ipc', 'list')
        out.should.include('---')
        out.should.match /BananaLib:/
        out.should.match /version: .1\.0./
        out.should.match /description: Full of chunky bananas./
      end

    end

    #-------------------------------------------------------------------------#

  end
end
