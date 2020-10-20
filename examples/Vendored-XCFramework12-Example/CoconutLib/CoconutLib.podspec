Pod::Spec.new do |s|
  s.name         = 'CoconutLib'
  s.version      = '1.0'
  s.authors      = 'Coconut Corp', { 'Monkey Boy' => 'monkey@coconut-corp.local' }
  s.homepage     = 'http://coconut-corp.local/coconut-lib.html'
  s.summary      = 'Coconuts For the Win.'
  s.description  = 'All the Coconuts'
  s.source       = { :git => 'http://coconut-corp.local/coconut-lib.git', :tag => 'v1.0' }
  s.license      = {
    :type => 'MIT',
    :text => 'Permission is hereby granted ...'
  }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.watchos.deployment_target = '3.0'
  s.tvos.deployment_target = '13.0'

  s.vendored_frameworks = 'build/CoconutLib.xcframework'
end
