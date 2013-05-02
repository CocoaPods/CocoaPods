Pod::Spec.new do |s|
  s.name         = 'Reachability'
  s.version      = '3.1.0'
  s.license      = 'BSD'
  s.homepage     = 'https://github.com/tonymillion/Reachability'
  s.authors      = { 'Tony Million' => 'tonymillion@gmail.com' }
  s.summary      = 'ARC and GCD Compatible Reachability Class for iOS. Drop in replacement for Apple Reachability.'
  s.source       = { :git => 'https://github.com/tonymillion/Reachability.git', :tag => 'v3.1.0' }
  s.source_files = 'Reachability.{h,m}', 'TestClass.{h,m}'
  s.framework    = 'SystemConfiguration'
  s.requires_arc = false

  def s.pre_install(pod, target_definition)
    # Replace strings in existing files
    pod.source_files.each do |file|
      replaced = file.read.gsub("kReachabilityChangedNotification", "kTEST")
      File.open(file, 'w') { |f| f.write(replaced) }
    end

    # Add new files
    File.open(pod.root + "TestClass.h", 'w') { |file| file.write("// TEST") }
    File.open(pod.root + "TestClass.m", 'w') { |file| file.write("// TEST") }
  end

  def s.post_install(library)
    dependencies = library.dependencies.map(&:to_s) * ", "
    File.open(library.sandbox_dir + "DependenciesList.txt", 'w') { |file| file.write(dependencies) }
  end
end
