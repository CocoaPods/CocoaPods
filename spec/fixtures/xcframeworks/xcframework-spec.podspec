Pod::Spec.new do |s|
  s.name             = 'xcframework-spec'
  s.version          = '1.0'
  s.author           = { 'xcframework-spec' => 'xcframework-spec@xcframework-spec.com' }
  s.summary          = 'Use this podspec for tests to point to different xcframeworks for testing'
  s.description      = 'Use this podspec for tests to point to different xcframeworks for testing'
  s.homepage         = 'http://xcframework-spec.com'
  s.source          = { :git => 'http://xcframework-spec-corp.local/xcframework-spec-lib.git', :tag => 'v1.0' }
  s.license          = 'MIT'

  s.platform     = :ios, '8.0'
end
