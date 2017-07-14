Pod::Spec.new do |s|
  s.name         = 'MinionsLib'
  s.version      = '1.0'
  s.authors      = 'Minions Corp', { 'Stuart' => 'stuart@minions-corp.local' }
  s.homepage     = 'http://minions-corp.local/minions-lib.html'
  s.summary      = 'Minions!'
  s.description  = 'Despicable Me'
  s.source       = { :git => 'http://minions-corp.local/minions-lib.git', :tag => 'v1.0' }
  s.license      = {
    :type => 'MIT',
    :file => 'LICENSE',
    :text => 'Permission is hereby granted ...'
  }
  s.source_files        = 'Classes/**/*'
end
