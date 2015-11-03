Pod::Spec.new do |s|
  s.name         = 'CrossRepoDependent'
  s.version      = '1.0'
  s.authors      = 'Ned Needy', { 'Mr. Needy' => 'needy@example.local' }
  s.homepage     = 'http://example.local/cross-repo-dependent.html'
  s.summary      = 'I\'m dependent upon another spec repo to resolve my dependencies.'
  s.description  = 'I\'m dependent upon another spec repo to resolve my dependencies.'
  s.platform     = :ios

  s.source       = { :git => 'http://example.local/cross-repo-dependent.git', :tag => 'v1.0' }
  s.source_files = 'Classes/*.{h,m}', 'Vendor'
  s.dependency   'AFNetworking', '2.4.0'
  s.license      = {
    :type => 'MIT',
    :file => 'LICENSE',
    :text => 'Permission is hereby granted ...'
  }
end
