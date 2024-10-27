Pod::Spec.new do |s|
  s.name             = "Pod3"
  s.version          = "1.0"
  s.summary          = "Pod3"
  s.description      = <<-DESC
                        Pod3
                       DESC
  s.homepage         = "https://github.com/CocoaPods/CocoaPods/issues/5362"
  s.license          = 'Proprietary'
  s.author           = { "Peter Wiesner" => "" }
  s.source           = {:path => "."}
  s.platform         = :ios, '8.0'
  s.requires_arc     = true

  s.subspec 's3' do |s3|
    s3.dependency 'Pod1/s2'
    s3.source_files  = '*.{h,m}'
  end
end
