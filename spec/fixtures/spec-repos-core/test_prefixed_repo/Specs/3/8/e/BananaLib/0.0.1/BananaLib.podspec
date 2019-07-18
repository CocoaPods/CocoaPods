Pod::Spec.new do |s|
  s.name         = 'BananaLib'
  s.version      = '0.0.1'
  s.authors      = 'Banana Corp', { 'Monkey Boy' => 'monkey@banana-corp.local' }
  s.homepage     = 'http://banana-corp.local/banana-lib.html'
  s.summary      = 'Chunky bananas!'
  s.description  = 'Full of chunky bananas.'
  s.source       = { :git => 'http://banana-corp.local/banana-lib.git', :commit => 'dbf863b4d7cf6c22d4bf89969fe7505c61950958' }
  s.source_files = 'Classes/*.{h,m}', 'Vendor'
  s.xcconfig     = { 'OTHER_LDFLAGS' => '-framework SystemConfiguration' }
  s.prefix_header_file = 'Classes/BananaLib.pch'
  s.resources    = "Resources/*.png"
  s.dependency   'monkey', '~> 1.0.1', '< 1.0.9'
  s.license      = {
    :type => 'MIT',
    :file => 'LICENSE',
    :text => 'Permission is hereby granted ...'
  }
end
