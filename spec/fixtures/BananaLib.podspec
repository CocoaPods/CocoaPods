Pod::Spec.new do |s|

  # Root attributes
  s.name         = 'BananaLib'
  s.version      = '1.0'
  s.authors      = 'Banana Corp', { 'Monkey Boy' => 'monkey@banana-corp.local' }
  s.homepage     = 'http://banana-corp.local/banana-lib.html'
  s.summary      = 'Chunky bananas!'
  s.description  = 'Full of chunky bananas.'
  s.source       = { :git => 'http://banana-corp.local/banana-lib.git', :tag => 'v1.0' }
  s.license      = {
    :type => 'MIT',
    :file => 'LICENSE',
    :text => 'Permission is hereby granted ...'
  }

  # Platform
  s.platform = :ios, '4.3'

  # File patterns
  s.source_files     = 'Classes/*.{h,m}', 'Vendor'
  s.ios.source_files = 'Classes_ios/*.{h,m}'
  s.resources        = "Resources/*.png"

  # Build settings
  s.pod_target_xcconfig = { 'OTHER_LDFLAGS' => '-framework SystemConfiguration' }
  s.prefix_header_file = 'Classes/BananaLib.pch'
  s.requires_arc       = true

  # Dependencies
  s.dependency   'monkey', '~> 1.0.1', '< 1.0.9'
  s.subspec "GreenBanana" do |ss|
    ss.source_files = 'GreenBanana'
    ss.dependency 'AFNetworking'
  end

  s.subspec "YellowBanana" do |ss|
    ss.source_files = 'YellowBanana'
    ss.dependency 'SDWebImage'
  end
end
