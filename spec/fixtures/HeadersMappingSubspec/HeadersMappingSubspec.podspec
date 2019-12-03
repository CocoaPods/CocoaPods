Pod::Spec.new do |s|
  s.name         = 'HeadersMappingSubspec'
  s.version      = '1.0'
  s.authors      = 'Mapping Corp'
  s.homepage     = 'http://mapping-corp.local/headers-mapping-subspec.html'
  s.summary      = 'Spec where subspecs define header_mapping_dirs'
  s.description  = 'Breaking things.'
  s.source       = { :git => 'http://mapping-corp.local/headers-mapping-subspec.git', :tag => 'v1.0' }
  s.license      = {
    :type => 'MIT',
    :text => 'Permission is hereby granted ...'
  }

  s.module_map = 'HeadersMappingSubspec.modulemap'

  s.source_files = '*.{h,m}'

  s.subspec 'Interface' do |ss|
    ss.header_mappings_dir = 'include/mapping'
    ss.source_files = 'include/mapping/*.h'
  end

  s.subspec 'Implementation' do |ss|
    ss.header_mappings_dir = '.'
    ss.source_files = 'external/magic/*.{h,c}'
    ss.private_header_files = 'external/magic/*.h'

    ss.dependency "#{s.name}/Interface", '1.0'
  end
end
