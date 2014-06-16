Pod::Spec.new do |s|

  s.name         = "NSString+STRegex"
  s.version      = "0.4.5"
  s.summary      = "some common regex."

  s.description  = <<-DESC
                    一些正则校验，判断邮箱，手机号码，车牌号，身份证号，网址，账号，密码，ip等。

                   DESC

  s.homepage     = "http://git.oschina.net/yanglishuan/NSString-STRegex"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "stlwtr" => "2008.yls@163.com" }
  s.platform     = :ios, '6.0'
  s.source       = { :git => "http://git.oschina.net/yanglishuan/NSString-STRegex.git", :tag => "0.4.5" }
  s.source_files  = 'Classes', 'NSString+STRegex/**/*.{h,m}'
  s.frameworks = 'UIKit', 'Foundation'
  s.requires_arc = true

end
