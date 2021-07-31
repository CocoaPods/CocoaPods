if (repo = ENV['COCOAPODS_SPEC_REPO'])
    source "#{repo}"
end

use_frameworks!

workspace 'Examples.xcworkspace'
project 'Headers Example.xcodeproj'

target 'App' do
  platform :osx, '10.9'
  pod 'FooHeadersPod', :path => 'FooHeadersPod'
  pod 'BarHeadersPod', :path => 'BarHeadersPod'
end
