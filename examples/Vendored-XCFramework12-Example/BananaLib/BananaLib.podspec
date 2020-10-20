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

  spec.vendored_frameworks = 'build/BananaLib.xcframework'
  spec.preserve_paths = 'build/BananaLib.dSYMs/iOS-Simulator.dSYM', 'build/BananaLib.dSYMs/iOS.dSYM', 'build/BananaLib.dSYMs/iOS-Catalyst.dSYM', 'build/BananaLib.dSYMs/macOS.dSYM', 'build/BananaLib.dSYMs/tvOS-Simulator.dSYM', 'build/BananaLib.dSYMs/tvOS.dSYM', 'build/BananaLib.dSYMs/watchOS-Simulator.dSYM', 'build/BananaLib.dSYMs/watchOS.dSYM'
end
