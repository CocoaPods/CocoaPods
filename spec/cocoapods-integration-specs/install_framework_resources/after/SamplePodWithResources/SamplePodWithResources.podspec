Pod::Spec.new do |s|
  s.name             = "SamplePodWithResources"
  s.version          = "0.1.0"
  s.summary          = "Internal Sample Pod with Resources for Integration Specs"
  s.homepage         = "https://github.com/CocoaPods/CocoaPods"
  s.license          = 'MIT'
  s.author           = { "Marius Rackwitz" => "git@mariusrackwitz.de" }
  s.source           = { :git => "https://github.com/CocoaPods/res.git", :tag => s.version.to_s }

  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.0'

  s.source_files = '*.m'
  s.resources = 'troll.png'
  s.resource_bundles = {
    'SamplePodWithResources' => ['logo.png']
  }
end
