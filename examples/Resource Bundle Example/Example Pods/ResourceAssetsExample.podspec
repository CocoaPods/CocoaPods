require_relative '../../defaults.rb'

Pod::Spec.new do |s|
  s.name                  = "ResourceAssetsExample"
  s.version               = "0.0.1"
  s.summary               = "Resource in a spec test pod."
  s.description           = "This spec specifies an asset catalog as a resource."

  s.ios.deployment_target = DEFAULT_IOS_DEPLOYMENT_TARGET
  s.osx.deployment_target = DEFAULT_MACOS_DEPLOYMENT_TARGET
  s.homepage              = "https://cocoapods.org"
  s.license               = { :type => "MIT", :file => "../../../LICENSE" }
  s.author                = { "Ben Asher" => "benasher44@gmail.com" }
  s.source                = { :path => "." }
  s.source_files          = "Example.swift"
  s.resource              = "Images.xcassets"
end
