Pod::Spec.new do |s|
  s.name         = "MixedPod"
  s.version      = "0.0.1"
  s.summary      = "A long description of objc."
  s.source       = { :git => "http://foo/objc.git", :tag => "#{s.version}" }
  s.authors = ['me']
  s.homepage = 'http://example.com'
  s.license = 'proprietary'

  s.source_files  = "src/**/*.{h,m,swift}"
  s.public_header_files = "src/**/*.h"

  s.dependency 'ObjCPod'
  s.dependency 'SwiftPod'

  s.ios.deployment_target = '9.0'
  s.macos.deployment_target = '10.10'
end
