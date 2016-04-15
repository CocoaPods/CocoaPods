Pod::Spec.new do |s|
  s.name                    = "VendoredFrameworkExample"
  s.version                 = "0.0.1"
  s.summary                 = "Vendored Framework in a spec test pod."
  s.description             = "This spec specifies a vendored framework."

  s.ios.deployment_target   = '8.0'
  s.homepage                = "https://cocoapods.org"
  s.license                 = { :type => "MIT", :file => "../../../../LICENSE" }
  s.author                  = "Mark Spanbroek"
  s.source                  = { :http => "https://github.com/AFNetworking/AFNetworking/releases/download/3.1.0/AFNetworking.framework.zip" }
  s.ios.vendored_frameworks = "**/iOS/AFNetworking.framework"
end

