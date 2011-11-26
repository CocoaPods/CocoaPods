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

namespace :gem do
  def gem_version
    require 'lib/cocoapods'
    Pod::VERSION
  end

  def gem_filename
    "cocoapods-#{Pod::VERSION}.gem"
  end

  desc "Build a gem for the current version"
  task :build do
    sh "gem build cocoapods.gemspec"
  end

  desc "Install a gem version of the current code"
  task :install => :build do
    sh "sudo macgem install #{gem_filename}"
    #sh "sudo macgem compile cocoapods"
  end

  desc "Build and install gem, then commit version change, tag it, and push everything"
  task :release do
    puts "You are about to release `#{gem_version}', is that correct? [y/n]"
    exit if STDIN.gets.strip.downcase != 'y'
    lines = `git diff --numstat`.strip.split("\n")
    if lines.size == 0
      puts "Change the version number yourself in lib/cocoapods.rb"
    elsif lines.size == 1 && lines.first.include?('lib/cocoapods.rb')
      # First see if the gem builds and installs
      Rake::Task['gem:install'].invoke
      # Then release
      sh "git commit lib/cocoapods.rb -m 'Release #{gem_version}'"
      sh "git tag -a #{gem_version} -m 'Release #{gem_version}'"
      sh "git push origin master"
      sh "git push --tags"
      sh "gem push #{gem_filename}"
    else
      puts "Only change the version number in a release commit!"
    end
  end
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

  desc "Run all specs and build all examples"
  task :ci => :all do
    sh "./bin/pod setup" # ensure the spec repo is up-to-date
    Rake::Task['examples:build'].invoke
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

namespace :examples do
  def examples
    require 'pathname'
    result = []
    examples = Pathname.new(File.expand_path('../examples', __FILE__))
    return [examples + ENV['example']] if ENV['example']
    examples.entries.each do |example|
      next if %w{ . .. }.include?(example.basename.to_s)
      example = examples + example
      next unless example.directory?
      result << example
    end
    result
  end

  desc "Open all example workspaced in Xcode, which recreates the schemes."
  task :recreate_workspace_schemes do
    examples.each do |example|
      Dir.chdir(example.to_s) do
        # TODO we need to open the workspace in Xcode at least once, otherwise it might not contain schemes.
        # The schemes do not seem to survive a SCM round-trip.
        sh "open '#{example.basename}.xcworkspace'"
        sleep 5
      end
    end
  end

  desc "Build all examples"
  task :build do
    examples.entries.each do |example|
      puts "Building example: #{example}"
      puts
      Dir.chdir(example.to_s) do
        sh "rm -rf Pods DerivedData"
        sh "#{'../../bin/' unless ENV['FROM_GEM']}pod install --verbose"
        command = "xcodebuild -workspace '#{example.basename}.xcworkspace' -scheme '#{example.basename}'"
        if (example + 'Podfile').read.include?('platform :ios')
          # Specifically build against the simulator SDK so we don't have to deal with code signing.
          command << " -sdk /Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.0.sdk"
        end
        sh command
      end
      puts
    end
  end
end

desc "Run all specs"
task :spec => 'spec:all'
