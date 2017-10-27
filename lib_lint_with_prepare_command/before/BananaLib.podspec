Pod::Spec.new do |s|
  s.name         = 'BananaLib'
  s.version      = '1.0'
  s.authors      = 'Banana Corp', { 'Monkey Boy' => 'monkey@banana-corp.local' }
  s.homepage     = 'https://github.com/CocoaPods/CocoaPods/tree/master/spec/fixtures'
  s.summary      = 'Chunky bananas!'
  s.description  = 'Full of chunky bananas.'
  s.source       = { :git => 'http://banana-corp.local/banana-lib.git', :tag => 'v1.0' }
  s.license      = {
    :type => 'MIT',
    :text => 'Permission is hereby granted ...'
  }
  s.platform        = :ios, '7.0'
  s.source_files    = 'Banana.{h,m}'
  s.prepare_command = <<-eos
    rm Banana.m
    echo "const int BKBananaMagicNumber = 3;" >> Banana.m
    mv BananaFruit.h Banana.h
  eos
end
