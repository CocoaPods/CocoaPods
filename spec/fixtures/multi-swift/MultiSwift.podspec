Pod::Spec.new do |s|
  s.name             = 'MultiSwift'
  s.version          = '1.0'
  s.author           = { 'MultiSwift' => 'multiswifter@multiswifter.com' }
  s.summary          = 'I can haz multi Swift!'
  s.description      = 'I said I can haz multi Swift'
  s.homepage         = 'http://multiswifter.com'
  s.source       = { :git => 'http://multiswifter-corp.local/multiswift-lib.git', :tag => 'v1.0' }
  s.license          = 'MIT'

  s.platform     = :ios, '8.0'

  s.source_files = 'Source/*.swift'

  s.swift_versions = ['3.2', '4.0']
end
