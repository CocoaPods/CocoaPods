Pod::Spec.new do |s|
  s.name = 'Alamofire'
  s.version = '0.0.1'
  s.license = 'MIT'
  s.summary = 'Elegant HTTP Networking in Swift'
  s.homepage = 'https://github.com/Alamofire/Alamofire'
  s.social_media_url = 'http://twitter.com/mattt'
  s.authors = { 'Mattt Thompson' => 'm@mattt.me' }
  s.source = { :git => 'https://github.com/Alamofire/Alamofire.git', :branch => 'master' }
  s.requires_arc = true

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'

  s.source_files = 'Source/*.swift'
end
