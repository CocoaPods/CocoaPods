require File.expand_path('../../../spec_helper', __FILE__)
require 'cocoapods/xcode/framework_paths'

module Pod
  module Xcode
    describe FrameworkPaths do
      describe '#==' do
        it 'compares equal framework paths as equal' do
          framework_paths0 = FrameworkPaths.new('${PODS_ROOT}/path/to/dynamic.framework',
                                                '${PODS_ROOT}/path/to/dynamic.framework.dSYM',
                                                ['${PODS_ROOT}/path/to/ABC.bcsymbolmap'])
          framework_paths1 = FrameworkPaths.new('${PODS_ROOT}/path/to/dynamic.framework',
                                                '${PODS_ROOT}/path/to/dynamic.framework.dSYM',
                                                ['${PODS_ROOT}/path/to/ABC.bcsymbolmap'])
          framework_paths0.should == framework_paths1
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
