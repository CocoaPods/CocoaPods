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
end

desc "Run all specs"
task :spec => 'spec:all'
