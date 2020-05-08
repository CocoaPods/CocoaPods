Pod::Spec.new do |s|
  s.name             = "※ikemen"
  s.version          = "0.6.0"
  s.module_name      = "Ikemen"
  s.summary          = "Swift way of Ruby Object#tap"

  s.description      = <<-DESC
  Swift way of Ruby Object#tap. for example:
  
  let nameLabel = UILabel() ※ {$0.text = "Name"}
                       DESC

  s.homepage         = "https://github.com/banjun/ikemen"
  s.license      = {
    :type => 'MIT',
    :text => 'Permission is hereby granted ...'
  }
  s.author           = { "banjun" => "banjun@gmail.com" }
  s.source           = { :git => "https://github.com/banjun/ikemen.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/banjun'

  s.ios.deployment_target = '8.0'
  s.swift_versions = ['5.0']
  s.requires_arc = true

  s.source_files = '*.swift'
end
