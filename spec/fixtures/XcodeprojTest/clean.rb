require 'fileutils'
require 'pathname'

root = Pathname.new(File.dirname(__FILE__)).realpath
excludes = %w(Podfile
              clean.rb
              XcodeprojTest
              XcodeprojTest/main.m
              XcodeprojTest.xcodeproj
              XcodeprojTest.xcodeproj/project.pbxproj
              XcodeprojTest.xcodeproj/project.xcworkspace
              XcodeprojTest.xcodeproj/project.xcworkspace/contents.xcworkspacedata
              XcodeprojTestPod
              XcodeprojTestPod/.gitignore
              XcodeprojTestPod/LICENSE
              XcodeprojTestPod/Subproject
              XcodeprojTestPod/Subproject/Subproject
              XcodeprojTestPod/Subproject/Subproject/Subproject.h
              XcodeprojTestPod/Subproject/Subproject/Subproject.m
              XcodeprojTestPod/Subproject/Subproject.xcodeproj
              XcodeprojTestPod/Subproject/Subproject.xcodeproj/project.pbxproj
              XcodeprojTestPod/Subproject/Subproject.xcodeproj/project.xcworkspace
              XcodeprojTestPod/Subproject/Subproject.xcodeproj/project.xcworkspace/contents.xcworkspacedata
              XcodeprojTestPod/XcodeprojTestPod.h
              XcodeprojTestPod/XcodeprojTestPod.m
              XcodeprojTestPod/XcodeprojTestPod.podspec).map { |p| root+p }


paths_in_dir = Dir[root.to_s+'/**/*'].map do |filename|
  Pathname.new(filename).realpath
end

files_to_remove = paths_in_dir.find_all do |path|
  !excludes.include?(path)
end

files_to_remove.sort.reverse.each do |file|
  unless file.to_s.start_with?(root.to_s)
    # Double-check that we don't remove lots of files like crazy
    raise Error, "A horrible internal error was about to happen!"
  end

  if File.directory?(file)
    FileUtils.rmdir(file)
  else
    FileUtils.rm(file)
  end
end
