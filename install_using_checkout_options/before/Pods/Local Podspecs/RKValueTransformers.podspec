Pod::Spec.new do |s|
  s.name     = 'RKValueTransformers'
  s.version  = '1.1.0'
  s.license  = 'Apache2'
  s.summary  = 'A powerful value transformation API extracted from RestKit.'
  s.homepage = 'https://github.com/RestKit/RKValueTransformers'
  s.authors  = { 'Blake Watters' => 'blakewatters@gmail.com', 'Samuel E. Giddins' => 'segiddins@segiddins.me' }
  s.source   = { :git => 'https://github.com/RestKit/RKValueTransformers.git', :tag => "v#{s.version}" }
  s.source_files = 'Code'
  s.requires_arc = true

  s.ios.deployment_target = '5.1.1'
  s.osx.deployment_target = '10.7'
end
