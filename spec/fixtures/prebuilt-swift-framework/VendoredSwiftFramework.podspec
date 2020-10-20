Pod::Spec.new do |s|
  s.name = 'VendoredSwiftFramework'
  s.version = '1.0.0'
  s.summary = 'Prebuilt Vendored Swift Framework'
  s.description  = 'Prebuilt VendoredSwiftFramework Framework'
  s.license      = { :type => 'Proprietary' }
  s.author       = { 'CP' => "https://cocoapods.org" }
  s.homepage  = "http://httpbin.org/html"
  s.source  = { :git => 'http://swiftvendoredframework.local/swiftvendoredframework.git', :tag => s.version.to_s }
  s.platform     = :ios, '12.0'
  s.swift_version = '5.0'
  s.vendored_frameworks = 'VendoredSwiftFramework.framework'
  s.frameworks = 'Foundation', 'UIKit'
end
