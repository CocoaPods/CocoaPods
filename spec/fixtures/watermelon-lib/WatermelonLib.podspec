Pod::Spec.new do |s|
  s.name         = 'WatermelonLib'
  s.version      = '1.0'
  s.authors      = 'Watermelon Corp', { 'Monkey Boy' => 'monkey@watermelon-corp.local' }
  s.homepage     = 'http://watermelon-corp.local/watermelon-lib.html'
  s.summary      = 'Watermelons For Summer.'
  s.description  = 'All the Watermelons'
  s.source       = { :git => 'http://watermelon-corp.local/watermelon-lib.git', :tag => 'v1.0' }
  s.license      = {
    :type => 'MIT',
    :text => 'Permission is hereby granted ...',
  }

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.11'

  s.source_files = 'Classes/*.{h,m}'

  s.test_spec do |test_spec|
    test_spec.source_files = 'Tests/*.{h,m,swift}'
    test_spec.dependency 'OCMock'
    test_spec.resources = 'App/*.txt'
    test_spec.resource_bundle = { 'WatermelonLibTestResources' => ['Tests/Resources/**/*'] }
  end

  s.test_spec 'UITests' do |test_spec|
    test_spec.test_type = :ui
    test_spec.requires_app_host = true
    test_spec.source_files = 'UITests/*.{h,m}'
  end

  s.test_spec 'SnapshotTests' do |test_spec|
    test_spec.requires_app_host = true
    test_spec.source_files = 'SnapshotTests/*.{h,m}'
    test_spec.dependency 'iOSSnapshotTestCase/Core'
  end

  s.app_spec do |app_spec|
    app_spec.source_files = 'App/*.swift'
    app_spec.resources = 'App/*.txt'
    app_spec.resource_bundle = { 'WatermelonLibExampleAppResources' => ['Tests/Resources/**/*'] }

    app_spec.pod_target_xcconfig = {
      'PRODUCT_NAME' => 'ExampleApp',
      'PRODUCT_SHORT_NAME' => 'ExampleApp',

      'INFOPLIST_FILE' => '${PODS_TARGET_SRCROOT}/App/App-Info.plist',

      'PRODUCT_BUNDLE_IDENTIFIER_Debug' => 'org.cocoapods.example.development',
      'PRODUCT_BUNDLE_IDENTIFIER_Release' => 'org.cocoapods.example',
      'PRODUCT_BUNDLE_IDENTIFIER' => '$(PRODUCT_BUNDLE_IDENTIFIER_$(CONFIGURATION))',

      'TARGETED_DEVICE_FAMILY' => '1', # iPhone-only
      'IPHONEOS_DEPLOYMENT_TARGET' => s.deployment_target(:ios),
      'SKIP_INSTALL' => 'NO',
      'ENABLE_BITCODE' => 'NO',
      'PRODUCT_MODULE_NAME' => 'ExampleAppSpec',

      'ASSETCATALOG_COMPILER_APPICON_NAME_Debug' => 'AppIcon-Debug',
      'ASSETCATALOG_COMPILER_APPICON_NAME_Release' => 'AppIcon',
      'ASSETCATALOG_COMPILER_APPICON_NAME' => '$(ASSETCATALOG_COMPILER_APPICON_NAME_$(CONFIGURATION))',

      'COPY_PHASE_STRIP_Debug' => 'NO',
      'COPY_PHASE_STRIP_Release' => 'YES',
      'COPY_PHASE_STRIP' => '$(COPY_PHASE_STRIP_$(CONFIGURATION))',

      'STRIP_INSTALLED_PRODUCT_Debug' => 'NO',
      'STRIP_INSTALLED_PRODUCT_Release' => 'YES',
      'STRIP_INSTALLED_PRODUCT' => '$(STRIP_INSTALLED_PRODUCT_$(CONFIGURATION))',

      'ENABLE_TESTABILITY_Debug' => 'YES',
      'ENABLE_TESTABILITY_Release' => 'NO',
      'ENABLE_TESTABILITY' => '$(ENABLE_TESTABILITY_$(CONFIGURATION))',

      'SWIFT_OPTIMIZATION_LEVEL_Debug' => '-Onone',
      'SWIFT_OPTIMIZATION_LEVEL_Release' => '-Owholemodule',
      'SWIFT_OPTIMIZATION_LEVEL' => '$(SWIFT_OPTIMIZATION_LEVEL_$(CONFIGURATION))',

      'CODE_SIGN_IDENTITY' => '$(ORG_PODS_CODE_SIGN_IDENTITY)',
      'CODE_SIGN_IDENTITY[sdk=iphoneos*]' => '$(ORG_PODS_CODE_SIGN_IDENTITY)',
      'PROVISIONING_PROFILE_SPECIFIER' => '$(ORG_PODS_PROVISIONING_PROFILE_SPECIFIER)',
      'DEVELOPMENT_TEAM' => '$(ORG_PODS_DEVELOPMENT_TEAM)',
    }

    app_spec.script_phase = { :name => 'Run Script', :script => 'set -eux; "${PODS_TARGET_SRCROOT}/Scripts/script.rb"', :shell_path => '/bin/sh' }
  end
end
