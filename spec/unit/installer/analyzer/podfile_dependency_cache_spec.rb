require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Analyzer
      describe PodfileDependencyCache do
        describe '.from_podfile' do
          it 'returns a warmed cache' do
            podfile = Podfile.new do
              pod 'A'
              target 'T1' do
                pod 'B'

                target 'T1T' do
                  inherit! :search_paths

                  pod 'C'
                end
              end
              target 'T2' do
                pod 'B'

                target 'T2T' do
                  inherit! :none

                  pod 'D'
                end
              end
            end

            cache = PodfileDependencyCache.from_podfile(podfile)
            cache.podfile_dependencies.should == podfile.dependencies

            target_definitions = podfile.target_definition_list
            cache.target_definition_list.should == target_definitions

            podfile.target_definition_list.each do |td|
              cache.target_definition_dependencies(td).should == td.dependencies
            end
            lambda { cache.target_definition_dependencies(nil) }.should.raise(ArgumentError)
          end
        end
      end
    end
  end
end
