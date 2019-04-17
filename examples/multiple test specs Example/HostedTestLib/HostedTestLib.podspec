Pod::Spec.new do |s|
  s.name             = 'HostedTestLib'
  s.version          = '0.1.0'
  s.summary          = 'A short description of HostedTestLib.'
  s.ios.deployment_target = '10.0'
  s.author           = { 'Jeff Overwatch' => 'jeff@overwatch.com' }
  s.homepage         = "https://github.com/"
  s.license          = 'MIT'
  s.source           = { :git => "https://github.com/<GITHUB_USERNAME>/HostedTestLib.git", :tag => s.version.to_s }
  
  s.source_files = 'Sources/**/*'
  s.dependency 'TestLib'
  
  s.swift_version = '4'
  
  s.test_spec 'UnitTests3' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.app_host_name = 'HostedTestLib/App'
    test_spec.dependency 'HostedTestLib/App'
    test_spec.source_files = 'UnitTests3/**/*'
    test_spec.dependency 'OCMock'
  end
  
  s.test_spec 'UnitTests4' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.app_host_name = 'TestLib/App'
    test_spec.dependency 'TestLib/App'

    test_spec.source_files = 'UnitTests4/**/*'
  end

  s.app_spec 'App' do |app_spec|
    app_spec.source_files = 'App/**/*'
    app_spec.pod_target_xcconfig = {
      'PRODUCT_NAME' => 'App Host'
    }
  end
end
