Pod::Spec.new do |s|
  s.name             = 'ByConfig'
  s.version          = '0.1.0'
  s.summary          = 'A short description of ByConfig.'
  s.ios.deployment_target = '10.0'
  s.author           = { 'Jeff Overwatch' => 'jeff@overwatch.com' }
  s.homepage         = "https://github.com/"
  s.license          = 'MIT'
  s.source           = { :git => "https://github.com/<GITHUB_USERNAME>/ByConfig.git", :tag => s.version.to_s }

  s.source_files = 'ByConfig/Classes/**/*'

  s.swift_version = '4'

  s.app_spec 'App' do |app_spec|
    app_spec.source_files = 'ByConfig/App/**/*'

    app_spec.dependency 'TestLib', configurations: %w[Debug]
    app_spec.dependency 'HostedTestLib'
  end
end
