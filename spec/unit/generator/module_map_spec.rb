require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Generator::ModuleMap do
    before do
      spec = fixture_spec('banana-lib/BananaLib.podspec')
      @pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios, [spec],
                                  [fixture_target_definition])
      @gen = Generator::ModuleMap.new(@pod_target)
    end

    it 'writes the module map to the disk' do
      path = temporary_directory + 'BananaLib.modulemap'
      @pod_target.stubs(:build_type => BuildType.dynamic_framework)
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
      @pod_target.stubs(:build_type => BuildType.static_library)
      @gen.save_as(path)
      path.read.should == <<-EOS.strip_heredoc
        module BananaLib {
          umbrella header "BananaLib-umbrella.h"

          export *
          module * { export * }
        }
      EOS
    end

    it 'writes the module map to the disk for a static framework' do
      path = temporary_directory + 'BananaLib.modulemap'
      @pod_target.stubs(:build_type => BuildType.static_framework)
      @gen.save_as(path)
      path.read.should == <<-EOS.strip_heredoc
        framework module BananaLib {
          umbrella header "BananaLib-umbrella.h"

          export *
          module * { export * }
        }
      EOS
    end

    it 'escapes double quotes properly for module map contents' do
      path = temporary_directory + 'BananaLib.modulemap'
      @pod_target.stubs(:umbrella_header_path).returns(Pathname.new('BananaLibWith"Quotes"-umbrella.h'))
      @pod_target.stubs(:build_type => BuildType.dynamic_framework)
      gen = Generator::ModuleMap.new(@pod_target)
      gen.save_as(path)
      path.read.should == <<-EOS.strip_heredoc
        framework module BananaLib {
          umbrella header "BananaLibWith\\"Quotes\\"-umbrella.h"

          export *
          module * { export * }
        }
      EOS
    end
  end
end
