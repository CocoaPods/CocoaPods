Pod::Spec.new do |s|
  s.name         = "Test"
  s.version      = "0.0.1"
  s.platform     = :ios, '5.0'
  s.license      = 'MIT'
  s.source       = { :git => "https://github.com/luisdelarosa/AFRaptureXMLRequestOperation.git" }
  s.source_files = 'AFRaptureXMLRequestOperation/*.{h,m}'
  s.requires_arc = true
  s.homepage     = "https://github.com/jansanz/AFRaptureXMLRequestOperation"
  s.summary      = "RaptureXML support for AFNetworking's AFHTTPClient."
  s.author       = { "Jan Sanchez" => "janfsd+github@gmail.com" }

  s.prefix_header_contents = "// Some great header comment"

  s.subspec 'Foo' do |subspec|
    subspec.source_files = 'FakeSubspec/*.{h,m}'
  end

end
