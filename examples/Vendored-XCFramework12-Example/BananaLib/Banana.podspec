Pod::Spec.new do |spec|
  spec.name         = "BananaLib"
  spec.version      = "0.0.1"
  spec.summary      = "Amazing bananalib that provides access to bananas"
  spec.description  = "Amazing bananalib that provides access to bananas"
  spec.homepage     = "http://github.com/CocoaPods/CocoaPods"
  spec.license      = "MIT"
  spec.author       = 'Coconut Corp', { 'Monkey Boy' => 'monkey@coconut-corp.local' }
  spec.source       = { :git => "https://github.com/CocoaPods/CocoaPods.git", :tag => "#{spec.version}" }

  spec.ios.deployment_target = '13.0'
  spec.osx.deployment_target = '10.15'
  spec.watchos.deployment_target = '3.0'
  spec.tvos.deployment_target = '13.0'

  spec.default_subspecs = 'DynamicFramework'

  spec.vendored_frameworks = 'build/BananaLib.xcframework'
end
