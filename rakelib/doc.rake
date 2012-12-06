require 'pathname'
ROOT = Pathname.new(File.expand_path('../../', __FILE__))
require 'active_support'
namespace :doc do
  task :load do
    unless (ROOT + 'rakelib/doc').exist?
      Dir.chdir(ROOT + 'rakelib') do
        sh "git clone git@github.com:CocoaPods/cocoapods.github.com.git doc"
      end
    end
    require ROOT + 'rakelib/doc/lib/doc'
  end

  desc 'Update vendor doc repo'
  task :update do
    Dir.chdir(ROOT + 'rakelib/doc') do
      sh "git checkout **/*.html"
      sh "git pull"
    end
  end

  desc 'Generate docs and push to remote'
  task :release => [:update, :generate] do
    Dir.chdir(ROOT + 'rakelib/doc') do
      sh "git add **/*.html"
      sh "git commit -m 'Update documentation [CocoaPods]'"
      sh "git push"
    end
  end

  task :generate => :load do
    generator = Pod::Doc::Gem.new(ROOT + 'cocoapods.gemspec', 'Pod')
    generator.render
    sh "open '#{generator.output_file}'"
  end
end

desc "Genereates the documentation"
task :doc => 'doc:generate'




