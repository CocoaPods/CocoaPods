
Pod::Spec.new do |spec|
  spec.name         = "BananaLib"
  spec.version      = "0.0.1"
  spec.summary      = "Amazing bananalib that provides access to bananas"
  spec.description  = <<-DESC
  Amazing bananalib that provides access to bananas
                   DESC

  spec.homepage     = "http://github.com/CocoaPods/CocoaPods"

  spec.license      = "MIT"
  spec.author       = 'Coconut Corp', { 'Monkey Boy' => 'monkey@coconut-corp.local' }
  spec.source       = { :git => "https://github.com/CocoaPods/CocoaPods.git", :tag => "#{spec.version}" }

  spec.ios.deployment_target = '13.0'
  spec.watchos.deployment_target = '3.0'
  spec.osx.deployment_target = '10.12'

  spec.default_subspecs = 'DynamicFramework'

  spec.subspec 'DynamicFramework' do |ss|
    ss.vendored_frameworks = 'DynamicFramework/CoconutLib.xcframework'
  end
  spec.subspec 'StaticFramework' do |ss|
    ss.vendored_frameworks = 'StaticFramework/CoconutLib.xcframework'
  end
  spec.subspec 'StaticLibrary' do |ss|
    ss.vendored_frameworks = 'StaticLibrary/CoconutLib.xcframework'
  end
end
