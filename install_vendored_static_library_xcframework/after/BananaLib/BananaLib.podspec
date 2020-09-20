
Pod::Spec.new do |spec|
  spec.name         = "BananaLib"
  spec.version      = "0.0.1"
  spec.summary      = "Amazing bananalib that provides access to bananas"

  spec.description  = <<-DESC
  Amazing bananalib that provides access to bananas
                   DESC

  spec.homepage     = "http://github.com/CocoaPods/CocoaPods"
  spec.license      = "MIT"

  spec.author       = { "CocoaPods" => "someone@cocoapods.org" }

  spec.platform     = :ios, "13.0"

  spec.source       = { :git => "https://github.com/CocoaPods/CocoaPods.git", :tag => "#{spec.version}" }
  spec.source_files  = "Classes", "Classes/**/*.{h,m}"
  spec.exclude_files = "Classes/Exclude"

  spec.vendored_frameworks = 'CoconutLib.xcframework'

  spec.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_XCFRAMEWORKS_BUILD_DIR}/CoconutLib/Headers"',
  }

  spec.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{h,m}'
  end
end
