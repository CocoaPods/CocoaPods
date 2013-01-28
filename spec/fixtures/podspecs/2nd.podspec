Pod::Spec.new do |s|
  s.name         = 'SecondLib'
  s.version      = '1.0'
  s.homepage     = 'https://secondlib.local/secondlib'
  s.summary      = 'The Second Lib'
  s.authors      = { 'Second Lib Creator' => 'creator@secondlib.local' }
  s.source       = { :git => 'https://secondlib.local/secondlib.git', :tag => '1.0' }
  s.source_files = 'Classes/*.{h,m}'
  s.license      = 'MIT'

  s.dependency     'SecondDep'
end
