Pod::Spec.new do |s|
  s.name             = "Pod1"
  s.version          = "1.0"
  s.summary          = "Pod1"
  s.description      = <<-DESC
                        Pod1
                       DESC
  s.homepage         = "https://github.com/CocoaPods/CocoaPods/issues/5362"
  s.license          = 'Proprietary'
  s.author           = { "Peter Wiesner" => "" }
  s.source           = {:path => "."}
  s.platform         = :ios, '8.0'
  s.requires_arc     = true
  s.source_files = './**/*.{h,m}'

  s.subspec 's1' do |s1|
    s1.source_files  = '*.{h,m}'
  end
  s.subspec 's2' do |s2|
    s2.dependency 'Pod2/s2'
    s2.source_files  = '*.{h,m}'
  end
end
