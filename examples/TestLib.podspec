Pod::Spec.new do
  name 'TestLib'
  version '1.0'
  summary 'A spec of a lib, to test that it too can be used to develop the lib.'
  source :git => 'http://example.local/test.git', :tag => 'v1.0'

  dependency 'SSZipArchive', '> 0.1'
  dependency 'JSONKit'
  dependency 'ASIHTTPRequest', '1.8'
end
