# Travis support
def on_rvm?
  `which ruby`.strip.include?('.rvm')
end

def rvm_ruby_dir
  @rvm_ruby_dir ||= File.expand_path('../..', `which ruby`.strip)
end

namespace :travis do
  # Used to create the deb package.
  #
  # Known to work with opencflite rev 248.
  task :prepare_deb do
    sh "sudo apt-get install subversion libicu-dev"
    sh "svn co https://opencflite.svn.sourceforge.net/svnroot/opencflite/trunk opencflite"
    sh "cd opencflite && ./configure --target=linux --with-uuid=/usr --with-tz-includes=./include --prefix=/usr/local && make && sudo make install"
    sh "sudo /sbin/ldconfig"
  end

  task :install_opencflite_debs do
    sh "mkdir -p debs"
    Dir.chdir("debs") do
      base_url = "https://github.com/downloads/CocoaPods/OpenCFLite"
      %w{ opencflite1_248-1_i386.deb opencflite-dev_248-1_i386.deb }.each do |deb|
        sh "wget #{File.join(base_url, deb)}" unless File.exist?(deb)
      end
      sh "sudo dpkg -i *.deb"
    end
  end

  task :fix_rvm_include_dir do
    unless File.exist?(File.join(rvm_ruby_dir, 'include'))
      # Make Ruby headers available, RVM seems to do not create a include dir on 1.8.7, but it does on 1.9.3.
      sh "mkdir '#{rvm_ruby_dir}/include'"
      sh "ln -s '#{rvm_ruby_dir}/lib/ruby/1.8/i686-linux' '#{rvm_ruby_dir}/include/ruby'"
    end
  end

  task :install do
    sh "git submodule update --init"
    sh "sudo apt-get install subversion"
    sh "env CFLAGS='-I#{rvm_ruby_dir}/include' bundle install"
  end

  task :setup => [:install_opencflite_debs, :fix_rvm_include_dir, :install]
end

namespace :gem do
  def gem_version
    require File.join(File.dirname(__FILE__), *%w[lib cocoapods])
    Pod::VERSION
  end

  def gem_filename
    "cocoapods-#{gem_version}.gem"
  end

  desc "Build a gem for the current version"
  task :build do
    sh "gem build cocoapods.gemspec"
  end

  desc "Install a gem version of the current code"
  task :install => :build do
    sh "gem install #{gem_filename}"
  end

  def silent_sh(command)
    #output = `/bin/sh -c '#{command}' 2>&1`
    output = `#{command} 2>&1`
    unless $?.success?
      puts output
      exit 1
    end
    output
  end

  desc "Run all specs, build and install gem, commit version change, tag version change, and push everything"
  task :release do
    unless ENV['SKIP_CHECKS']
      if `git symbolic-ref HEAD 2>/dev/null`.strip.split('/').last != 'master'
        $stderr.puts "[!] You need to be on the `master' branch in order to be able to do a release."
        exit 1
      end

      if `git tag`.strip.split("\n").include?(gem_version)
        $stderr.puts "[!] A tag for version `#{gem_version}' already exists. Change the version in lib/cocoapods.rb"
        exit 1
      end

      puts "You are about to release `#{gem_version}', is that correct? [y/n]"
      exit if $stdin.gets.strip.downcase != 'y'

      diff_lines = `git diff --numstat`.strip.split("\n")

      if diff_lines.size == 0 || !diff_lines.first.include?('lib/cocoapods.rb')
        $stderr.puts "[!] Change the version number yourself in lib/cocoapods.rb"
        exit 1
      end

      if diff_lines.size > 1 || !diff_lines.first.include?('lib/cocoapods.rb')
        $stderr.puts "[!] Only change the version number in a release commit!"
        exit 1
      end
    end

    # First check if the required Xcodeproj gem has ben pushed
    gem_spec = eval(File.read(File.expand_path('../cocoapods.gemspec', __FILE__)))
    xcodeproj = gem_spec.dependencies.find { |d| d.name == 'xcodeproj' }
    xcodeproj_version = xcodeproj.requirement.requirements.first.last.to_s

    puts "* Checking if xcodeproj #{xcodeproj_version} exists on the gem host"
    unless silent_sh("gem search --remote xcodeproj --version #{xcodeproj_version}").include?(xcodeproj_version)
      $stderr.puts "[!] The Xcodeproj version `#{xcodeproj_version}' required by " \
                   "this version of CocoaPods does not exist on the gem host. " \
                   "Either push that first, or fix the version requirement."
      exit 1
    end

    puts "* Running specs"
    silent_sh('rake spec:all')

    tmp = File.expand_path('../tmp', __FILE__)
    tmp_gems = File.join(tmp, 'gems')

    puts "* Testing gem installation (tmp/gems)"
    silent_sh "rm -rf '#{tmp}'"
    silent_sh "gem install --install-dir='#{tmp_gems}' #{gem_filename}"

    puts "* Building examples from gem (tmp/gems)"
    ENV['GEM_HOME'] = ENV['GEM_PATH'] = tmp_gems
    ENV['PATH']     = "#{tmp_gems}/bin:#{ENV['PATH']}"
    ENV['FROM_GEM'] = '1'
    silent_sh "rake examples:build"

    # Then release
    sh "git commit lib/cocoapods.rb -m 'Release #{gem_version}'"
    sh "git tag -a #{gem_version} -m 'Release #{gem_version}'"
    sh "git push origin master"
    sh "git push origin --tags"
    sh "gem push #{gem_filename}"
  end
end

namespace :spec do
  def specs(dir)
    FileList["spec/#{dir}/*_spec.rb"].shuffle.join(' ')
  end

  desc "Automatically run specs for updated files"
  task :kick do
    exec "bundle exec kicker -c"
  end

  desc "Run the unit specs"
  task :unit => :unpack_fixture_tarballs do
    sh "bundle exec bacon #{specs('unit/**')} -q"
  end

  desc "Run the functional specs"
  task :functional => :unpack_fixture_tarballs do
    sh "bundle exec bacon #{specs('functional/**')}"
  end

  desc "Run the integration spec"
  task :integration => :unpack_fixture_tarballs do
    sh "bundle exec bacon spec/integration_spec.rb"
  end

  task :all => :unpack_fixture_tarballs do
    sh "bundle exec bacon #{specs('**')}"
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

  task :clean_env => [:clean_vcr, :unpack_fixture_tarballs, "ext:cleanbuild"]
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
    sh "rm -rf ~/Library/Developer/Shared/Documentation/DocSets/org.cocoapods.*"
    examples.entries.each do |example|
      puts "Building example: #{example}"
      puts
      Dir.chdir(example.to_s) do
        sh "rm -rf Pods DerivedData"
        sh "#{'../../bin/' unless ENV['FROM_GEM']}pod install --verbose"
        command = "xcodebuild -workspace '#{example.basename}.xcworkspace' -scheme '#{example.basename}'"
        if (example + 'Podfile').read.include?('platform :ios')
          # Specifically build against the simulator SDK so we don't have to deal with code signing.
          root = File.exist?("/Applications/Xcode.app") ? "/Applications/Xcode.app/Contents" : ""
          command << " -sdk "
          command << Dir.glob("#{root}/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator*.sdk").last
        end
        sh command
      end
      puts
    end
  end
end

desc "Initializes your working copy to run the specs"
task :bootstrap do
  puts "Updating submodules..."
  `git submodule update --init --recursive`

  puts "Installing gems"
  `bundle install`
end

desc "Run all specs"
task :spec => 'spec:all'

task :default => :spec
