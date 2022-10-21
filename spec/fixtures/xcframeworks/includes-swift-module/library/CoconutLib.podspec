Pod::Spec.new do |s|
  s.name                          = 'CoconutLib'
  s.version                       = '1.0.0'
  s.summary                       = 'CoconutLib pod'
  s.homepage                      = 'www.google.com'
  s.license                       = { :type => 'MIT', :file => 'LICENSE' }
  s.author                        = { 'Team' => 'test' }
  s.source                        = { :git => 'url', :tag => s.version.to_s }
  s.swift_version                 = '5.0'
  s.ios.deployment_target         = '12.0'

  s.vendored_frameworks  = "#{s.name}.xcframework"

  s.source_files  = "Classes", "Classes/**/*.{h,m,swift}"

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/**/*.{h,m}'
  end

end
