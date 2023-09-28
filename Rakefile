# Bootstrap task
#-----------------------------------------------------------------------------#

desc 'Initializes your working copy to run the specs'
task :bootstrap, :use_bundle_dir? do |_, args|
  title 'Environment bootstrap'

  puts 'Updating submodules'
  execute_command 'git submodule update --init --recursive'

  if system('which bundle')
    puts 'Installing gems'
    if args[:use_bundle_dir?]
      execute_command 'env bundle install --path ./travis_bundle_dir'
    else
      execute_command 'env bundle install'
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
    title 'Building the gem'
  end

  task :check_submodules do
    title 'Ensuring submodules are initialized'
    submodule_help_msg = 'Run git submodule update --init --recursive to ensure submodules are initialized'
    raise submodule_help_msg if `git submodule status`.split("\n").any? do |line|
      line.start_with? '-'
    end
  end

  require 'bundler/gem_tasks'
  require 'bundler/setup'

  # Pre release
  #-----------------------------------------------------------------------------#

  desc 'Prepares for a release'
  task :pre_release do
  end

  # Post release
  #-----------------------------------------------------------------------------#

  desc 'Updates the last known version of CocoaPods in the specs repo'
  task :post_release do
    puts yellow("\n[!] The `post_release` task of CocoaPods no longer updates the master specs repo last known version. " \
                  'This is because of how slow it has become which can break the release process. ' \
                  "Please use the GitHub UI to update it to the #{gem_version} version.\n")
  end

  # Spec
  #-----------------------------------------------------------------------------#

  namespace :spec do
    def specs(dir)
      FileList["spec/#{dir}_spec.rb"].shuffle.join(' ')
    end

    #--------------------------------------#

    desc 'Automatically run specs for updated files'
    task :kick do
      exec 'bundle exec kicker -c'
    end

    #--------------------------------------#

    unit_specs_command = "bundle exec bacon #{specs('unit/**/*')}"

    desc 'Run the unit specs'
    task :unit => 'fixture_tarballs:unpack' do
      sh unit_specs_command
    end

    desc 'Run the unit specs quietly (fail fast, display only one failure)'
    task :unit_quiet => 'fixture_tarballs:unpack' do
      sh "#{unit_specs_command} -q"
    end

    #--------------------------------------#

    desc 'Run the functional specs'
    task :functional, [:spec] => 'fixture_tarballs:unpack' do |_t, args|
      args.with_defaults(:spec => '**/*')
      sh "bundle exec bacon #{specs("functional/#{args[:spec]}")}"
    end

    #--------------------------------------#

    desc 'Run the integration spec'
    task :integration do
      unless File.exist?('spec/cocoapods-integration-specs')
        $stderr.puts red('Integration files not checked out. Run `rake bootstrap`')
        exit 1
      end

      sh 'bundle exec bacon spec/integration.rb'
    end

    # Default task
    #--------------------------------------#
    #
    # The specs helper interfere with the integration 2 specs and thus they need
    # to be run separately.
    #
    task :all => 'fixture_tarballs:unpack' do
      tasks = ENV.fetch('COCOAPODS_CI_TASKS') { 'ALL' }.upcase.split(/\s+/)
      if %w(ALL SPECS EXAMPLES LINT).&(tasks).empty?
        raise "Unknown tasks #{tasks} -- supported options for COCOAPODS_CI_TASKS are " \
              'ALL, SPECS, EXAMPLES, LINT'
      end
      specs = %w(ALL SPECS).&(tasks).any?
      examples = %w(ALL EXAMPLES).&(tasks).any?
      lint = %w(ALL LINT).&(tasks).any?

      # Forcing colored to be included on String before Term::ANSIColor, so that Inch will work correctly.
      require 'colored2'
      ENV['GENERATE_COVERAGE'] = 'true'
      puts "\033[0;32mUsing #{`ruby --version`}\033[0m"

      if specs
        title 'Running the specs'
        sh "bundle exec bacon #{specs('**/*')}"

        title 'Running Integration tests'
        sh 'bundle exec bacon spec/integration.rb'
      end

      if examples && ENV['SKIP_EXAMPLES'].nil?
        title 'Running examples'
        Rake::Task['examples:build'].invoke
      end

      if lint
        title 'Running RuboCop'
        Rake::Task['rubocop'].invoke

        title 'Running Inch'
        Rake::Task['inch'].invoke

        unless ENV['CI'].nil?
          title 'Running Danger'
          # The obfuscated token is hard-coded into the repo because GitHub's Actions have no option to make a secret
          # available to PRs from forks. This token belongs to @CocoaPodsBarista and has no permissions except posting
          # comments. The reason it is needed is to inform the PR author of things Danger has suggestions for.
          ENV['DANGER_GITHUB_API_TOKEN'] = [:d, 2, :c, :e, 4,
                                            6, 5, :d, 3, :c, :b, 3, 3,
                                            :b, 6, 4, 4, 8, 2, 3, 2, :f,
                                            1, 8, :d, 8, :a, 5, 1, 6,
                                            5, 4, 4, 2, :c, :e, 3,
                                            :b, 0, :b].map(&:to_s).join
          Rake::Task['danger'].invoke
        end
      end
    end

    namespace :fixture_tarballs do
      task :default => :unpack

      tarballs = FileList['spec/fixtures/**/*.tar.gz']

      desc 'Check fixture tarballs for pending changes'
      task :check_for_pending_changes do
        tarballs.each do |tarball|
          repo_dir = "#{File.dirname(tarball)}/#{File.basename(tarball, '.tar.gz')}"
          if Dir.exist?(repo_dir) && Dir.exist?("#{repo_dir}/.git") && !Dir.chdir(repo_dir) { `git status --porcelain`.empty? }
            puts red("[!] There are unsaved changes in '#{repo_dir}'. " \
              'Please commit everything and run `rake spec:fixture_tarballs:rebuild`.')
            exit 1
          end
        end
      end

      desc 'Rebuild all the fixture tarballs'
      task :rebuild => :check_for_pending_changes do
        tarballs.each do |tarball|
          basename = File.basename(tarball)
          untarred_basename = File.basename(tarball, '.tar.gz')
          sh "cd #{File.dirname(tarball)} rm #{basename} && env COPYFILE_DISABLE=1 tar -zcf #{basename} #{untarred_basename}"
        end
      end

      desc 'Unpacks all the fixture tarballs'
      task :unpack, :force do |_t, args|
        begin
          Rake::Task['spec:fixture_tarballs:check_for_pending_changes'].invoke
        rescue SystemExit
          exit 1 unless args[:force]
          puts 'Continue anyway because `force` was applied.'
        end
        tarballs.each do |tarball|
          basename = File.basename(tarball)
          Dir.chdir(File.dirname(tarball)) do
            sh "rm -rf #{basename[0..-8]} ; tar zxf #{basename}"
          end
        end
      end
    end

    desc 'Removes the stored VCR fixture'
    task :clean_vcr do
      sh 'rm -f spec/fixtures/vcr/tarballs.yml'
    end

    desc 'Rebuilds integration fixtures'
    task :rebuild_integration_fixtures do
      unless system('which hg')
        puts red('[!] Mercurial (`hg`) must be installed to rebuild the integration fixtures.')
        exit 1
      end
      title 'Running Integration tests'
      FileUtils.rm_rf 'tmp'
      title 'Building all the fixtures'
      sh('bundle exec bacon spec/integration.rb') {}
      title 'Storing fixtures'
      # Copy the files to the files produced by the specs to the after folders
      FileList['tmp/*/transformed'].each do |source|
        name = source.match(%r{^tmp/(.+)/transformed$})[1]
        destination = "spec/cocoapods-integration-specs/#{name}/after"
        if File.exist?(destination)
          FileUtils.rm_rf destination
          FileUtils.mv source, destination
        end
      end

      puts
      puts 'Integration fixtures updated, commit and push in the `spec/cocoapods-integration-specs` submodule'
    end

    task :clean_env => [:clean_vcr, 'fixture_tarballs:unpack', 'ext:cleanbuild']
  end

  # Examples
  #-----------------------------------------------------------------------------#

  task :examples => 'examples:build'
  namespace :examples do
    desc 'Open all example workspaces in Xcode, which recreates the schemes.'
    task :recreate_workspace_schemes do
      Dir['examples/*'].each do |example|
        Dir.chdir(example.to_s) do
          # TODO: we need to open the workspace in Xcode at least once, otherwise it might not contain schemes.
          # The schemes do not seem to survive a SCM round-trip.
          sh 'open *.xcworkspace'
          sleep 5
        end
      end
    end

    desc 'Build all examples'
    task :build do
      Bundler.require 'xcodeproj', :development
      Dir['examples/*'].sort.each do |dir|
        Dir.chdir(dir) do
          puts "Example: #{dir}"

          puts '    Installing Pods'
          # pod_command = ENV['FROM_GEM'] ? 'sandbox-pod' : 'bundle exec ../../bin/sandbox-pod'
          # TODO: The sandbox is blocking local git repos making bundler crash
          pod_command = ENV['FROM_GEM'] ? 'sandbox-pod' : 'bundle exec ../../bin/pod'

          execute_command 'rm -rf Pods'
          execute_command "#{pod_command} install --verbose --no-repo-update"

          workspace_path = 'Examples.xcworkspace'
          workspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
          workspace.schemes.each do |scheme_name, project_path|
            next if scheme_name == 'Pods'
            next if project_path.end_with? 'Pods.xcodeproj'
            build_action = scheme_name.start_with?('Test') ? 'test' : 'build'
            puts "    #{build_action.capitalize}ing scheme: #{scheme_name}"

            project = Xcodeproj::Project.open(project_path)
            target = project.targets.first
            scheme_target = project.targets.find { |t| t.name == scheme_name }
            target = scheme_target unless scheme_target.nil?

            xcodebuild_args = %W(
              xcodebuild -workspace #{workspace_path} -scheme #{scheme_name} clean #{build_action}
            )

            case platform = target.platform_name
            when :osx
              execute_command(*xcodebuild_args)
            when :ios
              xcodebuild_args.concat ['ONLY_ACTIVE_ARCH=NO', '-destination', 'platform=iOS Simulator,name=iPhone 11 Pro']
              execute_command(*xcodebuild_args)
            when :watchos
              xcodebuild_args.concat ['ONLY_ACTIVE_ARCH=NO', '-destination', 'platform=watchOS Simulator,name=Apple Watch Series 5 - 40mm']
            else
              raise "Unknown platform #{platform}"
            end
          end
        end
      end
    end
  end

  #-----------------------------------------------------------------------------#

  desc 'Run all specs'
  task :spec => [:check_submodules, 'spec:all']

  task :default => :spec

  #-- Rubocop ----------------------------------------------------------------#

  desc 'Check code against RuboCop rules'
  task :rubocop do
    sh 'bundle exec rubocop lib spec Rakefile'
  end

  #-- Inch -------------------------------------------------------------------#

  require 'inch_by_inch/rake_task'
  InchByInch::RakeTask.new

  #-- Danger -----------------------------------------------------------------#

  desc 'Run Danger to check PRs'
  task :danger do
    sh 'bundle exec danger' do |ok, _status|
      raise 'Danger has found errors. Please refer to your PR for more information.' unless ok
    end
  end

rescue LoadError, NameError => e
  $stderr.puts "\033[0;31m" \
    '[!] Some Rake tasks haven been disabled because the environment' \
    ' couldn’t be loaded. Be sure to run `rake bootstrap` first or use the ' \
    "VERBOSE environment variable to see errors.\e[0m"
  if ENV['VERBOSE']
    $stderr.puts e.message
    $stderr.puts e.backtrace
    $stderr.puts
  end
end

# Helpers
#-----------------------------------------------------------------------------#

def execute_command(*command)
  if ENV['VERBOSE']
    sh(*command)
  else
    args = command.size == 1 ? "#{command.first} 2>&1" : [*command, :err => %i(child out)]
    output = IO.popen(args, &:read)
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
  puts '-' * 80
  puts cyan_title
  puts '-' * 80
  puts
end

def green(string)
  "\033[0;32m#{string}\e[0m"
end

def red(string)
  "\033[0;31m#{string}\e[0m"
end

def yellow(string)
  "\033[0;33m#{string}\e[0m"
end
