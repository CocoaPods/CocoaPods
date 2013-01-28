Pod::Spec.new do |s|
  s.name         = 'FirstLib'
  s.version      = '1.0'
  s.homepage     = 'https://firstlib.local/firstlib'
  s.summary      = 'The First Lib'
  s.authors      = { 'First Lib Creator' => 'creator@firstlib.local' }
  s.source       = { :git => 'https://firstlib.local/firstlib.git', :tag => '1.0' }
  s.source_files = 'Classes/*.{h,m}'
  s.license      = 'MIT'

  s.dependency     'FirstDep'
end
