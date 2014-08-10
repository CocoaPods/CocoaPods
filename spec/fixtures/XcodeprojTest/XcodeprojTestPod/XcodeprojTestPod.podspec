Pod::Spec.new do |s|

  s.name         = "XcodeprojTestPod"
  s.version      = "1.0"
  s.summary      = "A pod for testing spec.xcodeproj attribute"

  s.description  = <<-DESC
                   A pod for testing CocoaPod's ability to add Xcode projects as subprojects
                   to specs.
                   DESC

  s.homepage     = "https://www.github.com/pereckerdal/XcodeprojTestPod"

  s.license      = 'MIT'


  s.author       = { "Per Eckerdal" => "per.eckerdal@gmail.com" }

  s.platform     = :osx

  s.source       = { :git => 'https://github.com/pereckerdal/XcodeprojTestPod.git',
                     :tag => "#{s.version}" }

  s.xcodeproj = { :project => 'Subproject/Subproject.xcodeproj',
                  :library_targets => ['Subproject'] }

  s.source_files  = '*.{h,m}', 'Subproject/**/*.h'
  s.public_header_files = '*.h'

end
