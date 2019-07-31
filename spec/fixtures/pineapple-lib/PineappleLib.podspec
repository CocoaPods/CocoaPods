Pod::Spec.new do |s|
  s.name         = 'PineappleLib'
  s.version      = '1.0'
  s.authors      = 'Pineapple Corp', { 'Monkey Boy' => 'monkey@pineapple-corp.local' }
  s.homepage     = 'http://pineapple-corp.local/pineapple-lib.html'
  s.summary      = 'Pineapples For Summer.'
  s.description  = 'All the Pineapples'
  s.source       = { :git => 'http://pineapple-corp.local/pineapple-lib.git', :tag => 'v1.0' }
  s.license      = {
    :type => 'MIT',
    :text => 'Permission is hereby granted ...',
  }

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.11'

  s.source_files = 'Classes/*.{h,m}'

  s.test_spec do |test_spec|
    test_spec.requires_app_host = true
    test_spec.app_host_name = 'Pineapple/App'
    test_spec.source_files = 'Tests/*.{h,m,swift}'
    test_spec.dependency 'Pineapple/App'
  end

  s.test_spec 'UI' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.app_host_name = 'Pineapple/App'
    test_spec.test_type = :ui
    test_spec.source_files = 'UITests/*.{h,m,swift}'
    test_spec.dependency 'Pineapple/App'
  end

  s.app_spec do |app_spec|
    app_spec.source_files = 'App/*.swift'
  end
end
