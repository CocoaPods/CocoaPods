Pod::Spec.new do |spec|
  spec.name         = "CoffeeMachine"
  spec.version      = "0.0.1"
  spec.summary      = "A short description of a CoffeeMachine."
  spec.description  = "A short description of a CoffeeMachine."
  spec.homepage     = "http://EXAMPLE/Coffee"
  spec.license      = "prop" 
  spec.author       = "CocoaPods"
  spec.source       = { :git => 'Version not found', :tag => "podify/#{ spec.version.to_s}"} 
  spec.source_files = "Sources/**/*.{h,m}"

  spec.dependency 'Coffee'
end
