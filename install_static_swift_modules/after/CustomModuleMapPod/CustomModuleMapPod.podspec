Pod::Spec.new do |s|
  s.name         = "CustomModuleMapPod"
  s.version      = "0.0.1"
  s.summary      = "A long description of CustomModuleMapPod."
  s.source       = { :git => "http://foo/CustomModuleMapPod.git", :tag => "#{s.version}" }
  s.authors = ['me']
  s.homepage = 'http://example.com'
  s.license = 'proprietary'

  s.source_files  = "src/**/*.{h,m,swift}"
  s.private_header_files = "src/Private/*.h"

  s.module_map = "src/CustomModuleMapPod.modulemap"

  s.ios.deployment_target = '9.0'
  s.macos.deployment_target = '10.10'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'test/**/*.{h,m,swift}'
    test_spec.framework = 'XCTest'
  end
end
