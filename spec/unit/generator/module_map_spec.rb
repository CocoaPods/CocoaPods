require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::ModuleMap do
    before do
      spec = fixture_spec('banana-lib/BananaLib.podspec')
      target_definition = Podfile::TargetDefinition.new(:default, nil)
      @pod_target = PodTarget.new([spec], target_definition, config.sandbox)
      @gen = Generator::ModuleMap.new(@pod_target)
    end

    it 'writes the module map to the disk' do
      path = temporary_directory + 'BananaLib.modulemap'
      @gen.save_as(path)
      path.read.should == <<-EOS.strip_heredoc
        framework module BananaLib {
          umbrella header "Pods-default-BananaLib-umbrella.h"

          export *
          module * { export * }
        }
      EOS
    end

    it 'correctly adds private headers' do
      @gen.stubs(:private_headers).returns(['Private.h'])
      @gen.generate.should == <<-EOS.strip_heredoc
        framework module BananaLib {
          umbrella header "Pods-default-BananaLib-umbrella.h"

          export *
          module * { export * }

          private header "Private.h"
        }
      EOS
    end
  end
end
