desc "Compile the source files (as rbo files)"
task :compile do
  Dir.glob("lib/**/*.rb").each do |file|
    sh "macrubyc #{file} -C -o #{file}o"
  end
end

desc "Remove rbo files"
task :clean do
  sh "rm -f lib/**/*.rbo"
  sh "rm -f *.gem"
end

desc "Install a gem version of the current code"
task :install do
  require 'lib/cocoapods'
  sh "gem build cocoapods.gemspec"
  sh "sudo macgem install cocoapods-#{Pod::VERSION}.gem"
  sh "sudo macgem compile cocoapods"
end
