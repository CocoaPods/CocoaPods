Pod::Spec.new do |s|
  s.name         = "MNStaticTableViewController"
  s.version      = "1.0.0"
  s.summary      = "MNStaticTableViewController is a UITableViewController optimized for creating a tableview with static sections."
  s.homepage     = "https://github.com/madninja/MNStaticTableViewController"
  s.license      = {
  	:type => 'BSD',
  	:file => 'LICENSE'
  }
  s.author       = { 
  	"Marc Nijdam" => "http://imadjine.com" 
  }
  s.source       = { 
  	:git => "https://github.com/madninja/MNStaticTableViewController.git", 
  	:tag => s.version.to_s
  }
  s.source_files = 'MNStaticTableViewController/MNStaticTableViewController.{h,m}'
  s.requires_arc = true

  s.platform     = :ios, '5.0'
end
