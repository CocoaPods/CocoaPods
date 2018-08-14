Pod::Spec.new do |s|
  s.name         = 'WatermelonLib'
  s.version      = '1.0'
  s.authors      = 'Watermelon Corp', { 'Monkey Boy' => 'monkey@watermelon-corp.local' }
  s.homepage     = 'http://watermelon-corp.local/coconut-lib.html'
  s.summary      = 'Watermelons For Summer.'
  s.description  = 'All the Watermelons'
  s.source       = { :git => 'http://watermelon-corp.local/coconut-lib.git', :tag => 'v1.0' }
  s.license      = {
    :type => 'MIT',
    :text => 'Permission is hereby granted ...'
  }
  
  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.11'

  s.source_files        = 'Classes/*.{h,m}'

  s.test_spec do |test_spec|
    test_spec.source_files = 'Tests/*.{h,m,swift}'
    test_spec.dependency 'OCMock'
    test_spec.resource_bundle = { 'WatermelonLibTestResources' => ['Tests/Resources/**/*'] }
  end

  s.test_spec 'SnapshotTests' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = 'SnapshotTests/*.{h,m}'
    test_spec.dependency 'iOSSnapshotTestCase/Core'
  end
end
