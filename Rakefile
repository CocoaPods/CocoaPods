# Bootstrap task
#-----------------------------------------------------------------------------#

desc "Initializes your working copy to run the specs"
task :bootstrap, :use_bundle_dir? do |t, args|
  title "Environment bootstrap"

  puts "Updating submodules"
  execute_command "git submodule update --init --recursive"

  require 'rbconfig'
  if RbConfig::CONFIG['prefix'] == '/System/Library/Frameworks/Ruby.framework/Versions/2.0/usr'
    # Workaround Apple's mess. See https://github.com/CocoaPods/Xcodeproj/issues/137
    #
    # TODO This is not as correct as actually fixing the issue, figure out if we
    # can override these build flags:
    #
    # ENV['DLDFLAGS'] = '-undefined dynamic_lookup -multiply_defined suppress'
    ENV['ARCHFLAGS'] = '-Wno-error=unused-command-line-argument-hard-error-in-future'
  end

  if system('which bundle')
    puts "Installing gems"
    if args[:use_bundle_dir?]
      execute_command "env XCODEPROJ_BUILD=1 bundle install --path ./travis_bundle_dir"
    else
      execute_command "env XCODEPROJ_BUILD=1 bundle install"
    end
  else
    $stderr.puts "\033[0;31m" \
      "[!] Please install the bundler gem manually:\n" \
      '    $ [sudo] gem install bundler' \
      "\e[0m"
    exit 1
  end
end

begin

  task :build do
    title "Building the gem"
  end

  require "bundler/gem_tasks"

  # Post release
  #-----------------------------------------------------------------------------#
  
  desc "Updates the last know version of CocoaPods in the specs repo"
  task :post_release do
    title "Updating last known version in Specs repo"
    specs_branch = 'master'
    Dir.chdir('../Specs') do
      puts Dir.pwd
      sh "git checkout #{specs_branch}"
      sh "git pull"
  
      yaml_file  = 'CocoaPods-version.yml'
      unless File.exist?(yaml_file)
        $stderr.puts red("[!] Unable to find #{yaml_file}!")
        exit 1
      end
      require 'yaml'
      cocoapods_version = YAML.load_file(yaml_file)
      cocoapods_version['last'] = gem_version
      File.open(yaml_file, "w") do |f|
        f.write(cocoapods_version.to_yaml)
      end
  
      sh "git commit #{yaml_file} -m 'CocoaPods release #{gem_version}'"
      sh "git push"
    end
  end
  
  # Spec
  #-----------------------------------------------------------------------------#
  
  namespace :spec do
  
    def specs(dir)
      FileList["spec/#{dir}_spec.rb"].shuffle.join(' ')
    end
  
    #--------------------------------------#
  
    desc "Automatically run specs for updated files"
    task :kick do
      exec "bundle exec kicker -c"
    end
  
    #--------------------------------------#
  
    unit_specs_command = "bundle exec bacon #{specs('unit/**/*')}"
  
    desc "Run the unit specs"
    task :unit => :unpack_fixture_tarballs do
      sh unit_specs_command
    end
  
    desc "Run the unit specs quietly (fail fast, display only one failure)"
    task :unit_quiet => :unpack_fixture_tarballs do
      sh "#{unit_specs_command} -q"
    end
  
    #--------------------------------------#
  
    desc "Run the functional specs"
    task :functional, [:spec] => :unpack_fixture_tarballs do |t, args|
      args.with_defaults(:spec => '**/*')
      sh "bundle exec bacon #{specs("functional/#{args[:spec]}")}"
    end
  
    #--------------------------------------#
  
    desc "Run the integration spec"
    task :integration do
      unless File.exists?('spec/cocoapods-integration-specs')
        $stderr.puts red("Integration files not checked out. Run `rake bootstrap`")
        exit 1
      end
  
      sh "bundle exec bacon spec/integration.rb"
    end
  
    # Default task
    #--------------------------------------#
    #
    # The specs helper interfere with the integration 2 specs and thus they need
    # to be run separately.
    #
    task :all => :unpack_fixture_tarballs do
      ENV['GENERATE_COVERAGE'] = 'true'
      puts "\033[0;32mUsing #{`ruby --version`}\033[0m"
  
      title 'Running the specs'
      sh    "bundle exec bacon #{specs('**/*')}"
  
      title 'Running Integration tests'
      sh    "bundle exec bacon spec/integration.rb"
  
      title 'Running examples'
      Rake::Task['examples:build'].invoke
    end
  
    desc "Rebuild all the fixture tarballs"
    task :rebuild_fixture_tarballs do
      tarballs = FileList['spec/fixtures/**/*.tar.gz']
      tarballs.each do |tarball|
        basename = File.basename(tarball)
        sh "cd #{File.dirname(tarball)} && rm #{basename} && env COPYFILE_DISABLE=1 tar -zcf #{basename} #{basename[0..-8]}"
      end
    end
  
    desc "Unpacks all the fixture tarballs"
    task :unpack_fixture_tarballs do
      tarballs = FileList['spec/fixtures/**/*.tar.gz']
      tarballs.each do |tarball|
        basename = File.basename(tarball)
        Dir.chdir(File.dirname(tarball)) do
          sh "rm -rf #{basename[0..-8]} && tar zxf #{basename}"
        end
      end
    end
  
    desc "Removes the stored VCR fixture"
    task :clean_vcr do
      sh "rm -f spec/fixtures/vcr/tarballs.yml"
    end
  
    desc "Rebuilds integration fixtures"
    task :rebuild_integration_fixtures do
      title 'Running Integration tests'
      sh 'rm -rf spec/cocoapods-integration-specs/tmp'
      Rake::Task['spec:integration'].invoke
  
      title 'Storing fixtures'
      # Copy the files to the files produced by the specs to the after folders
      FileList['tmp/*'].each do |source|
        destination = "spec/cocoapods-integration-specs/#{source.gsub('tmp/','')}/after"
        if File.exists?(destination)
          sh "rm -rf #{destination}"
          sh "mv #{source} #{destination}"
        end
      end
  
      # Remove files not used for the comparison
      # To keep the git diff clean
      files_to_delete = FileList['spec/cocoapods-integration-specs/*/after/{Podfile,*.podspec,**/*.xcodeproj,PodTest-hg-source}']
      files_to_delete.exclude('/spec/cocoapods-integration-specs/init_single_platform/**/*.*')
      files_to_delete.each do |file_to_delete|
        sh "rm -rf #{file_to_delete}"
      end
  
      puts
      puts "Integration fixtures updated, commit and push in the `spec/cocoapods-integration-specs` submodule"
    end
  
    task :clean_env => [:clean_vcr, :unpack_fixture_tarballs, "ext:cleanbuild"]
  end
  
  # Examples
  #-----------------------------------------------------------------------------#
  
  task :examples => "examples:build"
  namespace :examples do
  
    desc "Open all example workspaces in Xcode, which recreates the schemes."
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
      Dir.chdir("examples/AFNetworking Example") do
        puts "Installing Pods"
        # pod_command = ENV['FROM_GEM'] ? 'sandbox-pod' : 'bundle exec ../../bin/sandbox-pod'
        # TODO: The sandbox is blocking local git repos making bundler crash
        pod_command = ENV['FROM_GEM'] ? 'sandbox-pod' : 'bundle exec ../../bin/pod'
  
        execute_command "rm -rf Pods"
        execute_command "#{pod_command} install --verbose --no-repo-update"
  
        puts "Building example: AFNetworking Mac Example'"
        execute_command "xcodebuild -workspace 'AFNetworking Examples.xcworkspace' -scheme 'AFNetworking Example' clean install"
  
        puts "Building example: AFNetworking iOS Example'"
        xcode_version = `xcodebuild -version`.scan(/Xcode (.*)\n/).first.first
        major_version = xcode_version.split('.').first.to_i
        # Specifically build against the simulator SDK so we don't have to deal with code signing.
        if  major_version > 4
          execute_command "xcodebuild -workspace 'AFNetworking Examples.xcworkspace' -scheme 'AFNetworking iOS Example' clean install ONLY_ACTIVE_ARCH=NO -destination 'platform=iOS Simulator,name=iPhone Retina (4-inch)'"
        else
          sdk = Dir.glob("#{`xcode-select -print-path`.chomp}/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator*.sdk").last
          execute_command "xcodebuild -workspace 'AFNetworking Examples.xcworkspace' -scheme 'AFNetworking iOS Example' clean install ONLY_ACTIVE_ARCH=NO  -sdk #{sdk}"
        end
      end
    end
  end
  
  #-----------------------------------------------------------------------------#
  
  desc "Run all specs"
  task :spec => 'spec:all'
  
  task :default => :spec

rescue LoadError
  $stderr.puts "\033[0;31m" \
    '[!] Some Rake tasks haven been disabled because the environment' \
    ' couldn’t be loaded. Be sure to run `rake bootstrap` first.' \
    "\e[0m"
end

# Helpers
#-----------------------------------------------------------------------------#

def execute_command(command)
  if ENV['VERBOSE']
    sh(command)
  else
    output = `#{command} 2>&1`
    raise output unless $?.success?
  end
end

def gem_version
  require File.expand_path('../lib/cocoapods/gem_version.rb', __FILE__)
  Pod::VERSION
end

def title(title)
  cyan_title = "\033[0;36m#{title}\033[0m"
  puts
  puts "-" * 80
  puts cyan_title
  puts "-" * 80
  puts
end

def red(string)
  "\033[0;31m#{string}\e[0m"
end
