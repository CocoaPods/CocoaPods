Pod::Spec.new do |s|
  s.name         = 'Foo+Bar'
  s.version      = '1.0'
  s.authors      = 'FooBar Corp'
  s.homepage     = 'http://foobar-corp.local/foobar.html'
  s.summary      = 'Wohoo foobars!'
  s.description  = 'Silly foos, silly bars.'
  s.platform     = :ios

  s.source       = { :git => 'http://foobar-corp.local/foobar.git', :tag => '1.0' }
  s.source_files = 'Classes/*.{h,m}'
  s.license      = {
    :type => 'MIT',
    :file => 'LICENSE',
    :text => 'Permission is hereby granted ...'
  }
end
