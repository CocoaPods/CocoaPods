require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::ModuleMap do
    before do
      spec = fixture_spec('banana-lib/BananaLib.podspec')
      @pod_target = PodTarget.new([spec], [fixture_target_definition], config.sandbox)
      @gen = Generator::ModuleMap.new(@pod_target)
    end

    it 'writes the module map to the disk' do
      path = temporary_directory + 'BananaLib.modulemap'
      @pod_target.stubs(:requires_frameworks?).returns(true)
      @gen.save_as(path)
      path.read.should == <<-EOS.strip_heredoc
        framework module BananaLib {
          umbrella header "BananaLib-umbrella.h"

          export *
          module * { export * }
        }
      EOS
    end

    it 'writes the module map to the disk for a library' do
      path = temporary_directory + 'BananaLib.modulemap'
      @pod_target.stubs(:requires_frameworks?).returns(false)
      @gen.save_as(path)
      path.read.should == <<-EOS.strip_heredoc
        module BananaLib [system] {
          umbrella header "BananaLib-umbrella.h"

          export *
          module * { export * }
        }
      EOS
    end
  end
end
