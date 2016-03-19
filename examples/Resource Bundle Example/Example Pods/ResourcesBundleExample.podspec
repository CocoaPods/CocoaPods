Pod::Spec.new do |s|
  s.name                         = "ResourcesBundleExample"
  s.version                      = "0.0.1"
  s.summary                      = "Resources in a spec test pod."
  s.description                  = "This spec specifies images as resources."

  s.ios.deployment_target        = '8.0'
  s.osx.deployment_target        = '10.9'
  s.homepage                     = "https://cocoapods.org"
  s.license                      = { :type => "MIT", :file => "../../../LICENSE" }
  s.author                       = { "Ben Asher" => "benasher44@gmail.com" }
  s.source                       = { :path => "." }
  s.source_files                 = "Example.swift"
  s.resource_bundles             = {"ResourcesBundleExample" => ["Resources/*.jpg"] }
end
