Pod::Spec.new do |s|
  s.name                    = 'HeaderMappingsDirPod'
  s.version                 = '0.1.0'
  s.summary                 = 'Demonstrates using a set of advanced options all together.'
  s.description             = <<-DESC
                              * has private headers
                              * has a `header_mappings_dir`
                              * has a `module_map`
                              * explictly declare at least one of the private
                                headers in the module map
                              DESC
  s.source                  = { :git => 'https://github.com/CocoaPods/CocoaPods.git', :tag => "v#{s.version}" }
  s.homepage                = "https://github.com/CocoaPods/CocoaPods"
  s.author                  = { 'Example' => 'help@example.org' }
  s.license                 = { :type => 'MIT', :file => '../../../LICENSE' }

  s.public_header_files     = 'include/Foo.h', 'include/Bar/Bar.h'
  s.private_header_files    = 'include/Bar/Bar_Private.h'
  s.source_files            = '*.m', 'include/*.h', 'include/Bar/*.h'
  s.module_map              = 'module.modulemap'
  s.header_mappings_dir     = 'include'
  s.preserve_paths          = %w(include)

  s.osx.deployment_target   = '10.9'
end
