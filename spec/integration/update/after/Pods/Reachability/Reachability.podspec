Pod::Spec.new do |s|
  s.name         = 'Reachability'
  s.version      = '2.0.5'
  s.platform     = :ios
  s.homepage     = 'http://blog.ddg.com/?p=24'
  s.authors      = 'Apple', 'Donoho Design Group, LLC'
  s.summary      = 'A wrapper for the SystemConfiguration Reachability APIs.'
  s.description  = 'This is Apple’s example code of the SystemConfiguration Reachability APIs, ' \
                   'adapted by Andrew Donoho, split-off from the ASIHTTPRequest source. ' \
                   '(This code needs an actual maintainer.)'
  s.source       = { :git => 'git://github.com/CocoaPods/unmaintained-pod-Reachability.git', :tag => '2.0.5' }
  s.source_files = 'Reachability.{h,m}'
  s.framework    = 'SystemConfiguration'
end
