Pod::Spec.new do |s|
  s.name         = 'BananaLib'
  s.version      = '1.0'
  s.authors      = 'Banana Corp', { 'Monkey Boy' => 'monkey@banana-corp.local' }
  s.homepage     = 'http://banana-corp.local/banana-lib.html'
  s.summary      = 'Chunky bananas!'
  s.description  = 'Full of chunky bananas.'
  s.source       = { :git => 'http://banana-corp.local/banana-lib.git', :tag => 'v1.0' }
  s.license      = {
    :type => 'MIT',
    :text => 'Permission is hereby granted ...'
  }
  s.source_files        = 'Classes/*.{h,m}'
  s.public_header_files = 'Classes/Banana.h'
  s.private_header_files = 'Classes/BananaPrivate.h'
  s.module_map = 'BananaLib.modulemap'
end
