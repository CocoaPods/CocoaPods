Pod::Spec.new do |spec|
  spec.name = 'DepPod'
  spec.version = '1.0.0'

  spec.authors = ['CocoaPods']
  spec.license = 'MIT'
  spec.homepage = 'https://example.com'
  spec.source = { :git => 'https://example.com' }
  spec.summary = 'A summary'

  spec.source_files = 'src/**/*.{h,m}'
  spec.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }

  spec.dependency 'HeaderMappingsDirPod'
end