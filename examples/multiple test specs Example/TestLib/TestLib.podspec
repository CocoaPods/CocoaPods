Pod::Spec.new do |s|
  s.name             = 'TestLib'
  s.version          = '0.1.0'
  s.summary          = 'A short description of TestLib.'
  s.ios.deployment_target = '10.0'
  s.author           = { 'Jeff Overwatch' => 'jeff@overwatch.com' }
  s.homepage         = "https://github.com/"
  s.license          = 'MIT'
  s.source           = { :git => "https://github.com/<GITHUB_USERNAME>/TestLib.git", :tag => s.version.to_s }

  s.source_files = 'TestLib/Classes/**/*'

  s.swift_version = '4'

  s.test_spec 'UnitTests1' do |test_spec|
    test_spec.source_files = 'TestLib/UnitTests1/**/*'
    test_spec.dependency 'OCMock'
  end

  s.test_spec 'UnitTests2' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = 'TestLib/UnitTests2/**/*'
  end

  s.app_spec 'App' do |app_spec|
    app_spec.source_files = 'TestLib/App/**/*'
  end
end
