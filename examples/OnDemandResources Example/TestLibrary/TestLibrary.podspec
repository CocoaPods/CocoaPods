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

  s.ios.deployment_target = '9.0'

  s.swift_version = '4'

  s.source_files = 'TestLibrary/Classes/**/*'

  s.on_demand_resources = {
    't1' => ['on_demand_bundle1/*'],
    't2' => { :paths => ['on_demand_bundle2/*'], :category => :prefetched },
  }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }

  s.app_spec 'App1' do |app_spec|
    app_spec.source_files = 'App1/Classes/**/*'

    app_spec.on_demand_resources = {
      'a1' => { :paths => ['App1/app1_on_demand_bundle1/*'], :category => :initial_install }
    }
  end

  s.app_spec 'App2' do |app_spec|
    app_spec.source_files = 'App2/Classes/**/*'

    app_spec.on_demand_resources = {
      'a2' => { :paths => ['App2/app2_on_demand_bundle1/*'], :category => :initial_install }
    }
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/Classes/**/*'

    test_spec.app_host_name = 'TestLibrary/App1'
    test_spec.requires_app_host = true
    test_spec.dependency 'TestLibrary/App1'

    test_spec.on_demand_resources = {
      'test1' => ['Tests/test_on_demand_bundle/*']
    }
  end
end
