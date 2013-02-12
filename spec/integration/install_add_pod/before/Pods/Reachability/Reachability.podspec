Pod::Spec.new do |s|
  s.name         = 'Reachability'
  s.version      = '3.1.0'
  s.license      = 'BSD'
  s.homepage     = 'https://github.com/tonymillion/Reachability'
  s.authors      = { 'Tony Million' => 'tonymillion@gmail.com' }
  s.summary      = 'ARC and GCD Compatible Reachability Class for iOS. Drop in replacement for Apple Reachability.'
  s.source       = { :git => 'https://github.com/tonymillion/Reachability.git', :tag => 'v3.1.0' }
  s.source_files = 'Reachability.{h,m}'
  s.framework    = 'SystemConfiguration'
  s.requires_arc = false
end
