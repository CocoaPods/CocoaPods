#
# Be sure to run `pod lib lint TestLibrary.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'TestLibrary'
  s.version          = '0.1.0'
  s.summary          = 'A short description of TestLibrary.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/lizhuoli1126@126.com/TestLibrary'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'lizhuoli1126@126.com' => 'lizhuoli1126@126.com' }
  s.source           = { :git => 'https://github.com/lizhuoli1126@126.com/TestLibrary.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'TestLibrary/Classes/**/*'
  
  s.on_demand_resources = {
    't1' => ['on_demand_bundle1/*'],
    't2' => ['on_demand_bundle2/*']
  }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }


end
