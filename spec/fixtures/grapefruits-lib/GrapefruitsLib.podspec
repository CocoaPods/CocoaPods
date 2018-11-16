Pod::Spec.new do |s|
  s.name         = 'GrapefruitsLib'
  s.version      = '1.0'
  s.authors      = 'Grapefruits Corp', { 'Monkey Boy' => 'monkey@grapefruit-corp.local' }
  s.homepage     = 'http://grapefruit-corp.local/grapefruits-lib.html'
  s.summary      = 'Grapefruits for the Win.'
  s.description  = 'All the Grapefruits'
  s.source       = { :git => 'http://grapefruits-corp.local/grapefruits-lib.git', :tag => 'v1.0' }
  s.license      = {
    :type => 'MIT',
    :text => 'Permission is hereby granted ...'
  }
  s.source_files        = 'Classes/*.{h,m}'

  s.test_spec do |test_spec|
    test_spec.source_files = 'Tests/*.{h,m}'
    test_spec.dependency 'OCMock'
  end  

  s.app_spec do |app_spec|
    app_spec.source_files = 'App/*.{h,m}'
    app_spec.dependency 'BananaLib'
  end
end
