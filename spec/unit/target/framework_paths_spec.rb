require File.expand_path('../../../spec_helper', __FILE__)
require 'cocoapods/target/framework_paths'

module Pod
  class Target
    describe FrameworkPaths do
      describe '#==' do
        it 'compares equal framework paths as equal' do
          framework_paths_0 = FrameworkPaths.new('${PODS_ROOT}/path/to/dynamic.framework',
                                                 '${PODS_ROOT}/path/to/dynamic.framework.dSYM',
                                                 ['${PODS_ROOT}/path/to/ABC.bcsymbolmap'])
          framework_paths_1 = FrameworkPaths.new('${PODS_ROOT}/path/to/dynamic.framework',
                                                 '${PODS_ROOT}/path/to/dynamic.framework.dSYM',
                                                 ['${PODS_ROOT}/path/to/ABC.bcsymbolmap'])
          framework_paths_0.should == framework_paths_1
        end
      end

      describe '#all_paths' do
        it 'returns all paths' do
          framework_paths = FrameworkPaths.new('${PODS_ROOT}/path/to/dynamic.framework',
                                               '${PODS_ROOT}/path/to/dynamic.framework.dSYM',
                                               ['${PODS_ROOT}/path/to/ABC.bcsymbolmap'])
          framework_paths.all_paths.should == [
            '${PODS_ROOT}/path/to/dynamic.framework',
            '${PODS_ROOT}/path/to/dynamic.framework.dSYM',
            '${PODS_ROOT}/path/to/ABC.bcsymbolmap',
          ]
        end
      end
    end
  end
end
