class Array
  def move_to_front(name, by_basename = true)
    path = find { |f| (by_basename ? File.basename(f) : f) == name }
    delete(path)
    unshift(path)
  end
end

task :standalone do
  files = Dir.glob("lib/**/*.rb")
  files.move_to_front('executable.rb')
  files.move_to_front('lib/cocoapods/config.rb', false)
  files.move_to_front('cocoapods.rb')
  File.open('concatenated.rb', 'w') do |f|
    files.each do |file|
      File.read(file).split("\n").each do |line|
        f.puts(line) unless line.include?('autoload')
      end
    end
    f.puts 'Pod::Command.run(*ARGV)'
  end
  sh "macrubyc concatenated.rb -o pod"
end

####

desc "Compile the source files (as rbo files)"
task :compile do
  Dir.glob("lib/**/*.rb").each do |file|
    sh "macrubyc #{file} -C -o #{file}o"
  end
end

desc "Remove rbo files"
task :clean do
  sh "rm -f lib/**/*.rbo"
  sh "rm -f lib/**/*.o"
  sh "rm -f *.gem"
end

desc "Install a gem version of the current code"
task :install do
  require 'lib/cocoapods'
  sh "gem build cocoapods.gemspec"
  sh "sudo macgem install cocoapods-#{Pod::VERSION}.gem"
  sh "sudo macgem compile cocoapods"
end

namespace :spec do
  desc "Run the unit specs"
  task :unit do
    sh "macbacon spec/unit/**/*_spec.rb"
  end

  desc "Run the functional specs"
  task :functional do
    sh "macbacon spec/functional/*_spec.rb"
  end

  desc "Run the integration spec"
  task :integration do
    sh "macbacon spec/integration_spec.rb"
  end

  task :all do
    sh "macbacon -a"
  end

  desc "Rebuild all the fixture tarballs"
  task :rebuild_fixture_tarballs do
    tarballs = FileList['spec/fixtures/**/*.tar.gz']
    tarballs.each do |tarball|
      basename = File.basename(tarball)
      sh "cd #{File.dirname(tarball)} && rm #{basename} && tar -zcf #{basename} #{basename[0..-8]}"
    end
  end
end

desc "Build all examples"
task :build_examples do
  require 'pathname'
  examples = Pathname.new(File.expand_path('../examples', __FILE__))
  examples.entries.each do |example|
    next if %w{ . .. ConfigureTest MacRubySample }.include?(example.basename.to_s)
    example = examples + example
    next unless example.directory?
    puts "Building example: #{example}"
    puts
    Dir.chdir(example.to_s) do
      sh "rm -rf Pods DerivedData"
      sh "../../bin/pod install --verbose"
      command = "xcodebuild -workspace '#{example.basename}.xcworkspace' -scheme '#{example.basename}'"
      if (example + 'Podfile').read.include?('platform :ios')
        command << " -sdk /Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.0.sdk"
      end
      sh command
    end
    puts
  end
end

desc "Dumps a Xcode project as YAML, meant for diffing"
task :dump_xcodeproj do
  require 'yaml'
  hash = NSDictionary.dictionaryWithContentsOfFile(File.join(ENV['xcodeproj'], 'project.pbxproj'))
  objects = hash['objects']
  result = objects.values.map do |object|
    if children = object['children']
      object['children'] = children.map do |uuid|
        child = objects[uuid]
        child['path'] || child['name']
      end.sort
    elsif files = object['files']
      object['files'] = files.map do |uuid|
        build_file = objects[uuid]
        file = objects[build_file['fileRef']]
        file['path']
      end
    elsif file_ref = object['fileRef']
      file = objects[file_ref]
      object['file'] = file['path']
    end
    object
  end
  result.each do |object|
    object.delete('fileRef')
  end
  result = result.sort_by do |object|
    [object['isa'], object['file'], object['path'], object['name']].compact
  end
  puts result.to_yaml
end

desc "Run all specs"
task :spec => 'spec:all'
