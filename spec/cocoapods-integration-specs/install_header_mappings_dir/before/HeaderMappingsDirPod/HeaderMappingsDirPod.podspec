Pod::Spec.new do |spec|
  spec.name = 'HeaderMappingsDirPod'
  spec.version = '1.0.0'

  spec.authors = ['CocoaPods']
  spec.license = 'MIT'
  spec.homepage = 'https://example.com'
  spec.source = { :git => 'https://example.com' }
  spec.summary = 'A summary'

  spec.source_files = 'src/**/*.{h,m}', 'include/**/*.h'
  spec.header_mappings_dir = 'include'
  spec.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end