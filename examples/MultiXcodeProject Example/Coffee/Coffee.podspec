Pod::Spec.new do |spec|
  spec.name         = "Coffee"
  spec.version      = "0.0.1"
  spec.summary      = "A short description of Coffee."
  spec.description  = "A short description of Coffee."
  spec.homepage     = "http://EXAMPLE/Coffee"
  spec.license      = "prop" 
  spec.author       = "CocoaPods"
  spec.source       = { :git => 'Version not found', :tag => "podify/#{ spec.version.to_s}"} 
  spec.source_files = "Sources/**/*.{h,m}"
end
