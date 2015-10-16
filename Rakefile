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

  require 'bundler/gem_tasks'

  # Pre release
  #-----------------------------------------------------------------------------#

  desc 'Prepares for a release'
  task :pre_release do
    unless File.exist?('../Specs')
      raise 'Ensure that the specs repo exits in the `../Specs` location'
    end
  end

  # Post release
  #-----------------------------------------------------------------------------#

  desc 'Updates the last know version of CocoaPods in the specs repo'
  task :post_release do
    title 'Updating last known version in Specs repo'
    specs_branch = 'master'
    Dir.chdir('../Specs') do
      puts Dir.pwd
      sh "git checkout #{specs_branch}"
      sh 'git pull'

      yaml_file = 'CocoaPods-version.yml'
      unless File.exist?(yaml_file)
        $stderr.puts red("[!] Unable to find #{yaml_file}!")
        exit 1
      end
      require 'yaml'
      cocoapods_version = YAML.load_file(yaml_file)
      cocoapods_version['last'] = gem_version
      File.open(yaml_file, 'w') do |f|
        f.write(cocoapods_version.to_yaml)
      end

      sh "git commit #{yaml_file} -m 'CocoaPods release #{gem_version}'"
      sh 'git push'
    end
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
      # Forcing colored to be included on String before Term::ANSIColor, so that Inch will work correctly.
      require 'colored'
      ENV['GENERATE_COVERAGE'] = 'true'
      puts "\033[0;32mUsing #{`ruby --version`}\033[0m"

      title 'Running the specs'
      sh "bundle exec bacon #{specs('**/*')}"

      title 'Running Integration tests'
      sh 'bundle exec bacon spec/integration.rb'

      title 'Running examples'
      Rake::Task['examples:build'].invoke

      title 'Running RuboCop'
      Rake::Task['rubocop'].invoke

      title 'Running Inch'
      Rake::Task['inch:spec'].invoke
    end

    namespace :fixture_tarballs do
      task :default => :unpack

      desc 'Check fixture tarballs for pending changes'
      task :check_for_pending_changes do
        repo_dir = 'spec/fixtures/banana-lib'
        if Dir.exist?(repo_dir) && !Dir.chdir(repo_dir) { `git status --porcelain`.empty? }
          puts red("[!] There are unsaved changes in '#{repo_dir}'. " \
            'Please commit everything and run `rake spec:fixture_tarballs:rebuild`.')
          exit 1
        end
      end

      desc 'Rebuild all the fixture tarballs'
      task :rebuild => :check_for_pending_changes do
        tarballs = FileList['spec/fixtures/**/*.tar.gz']
        tarballs.each do |tarball|
          basename = File.basename(tarball)
          sh "cd #{File.dirname(tarball)} && rm #{basename} && env COPYFILE_DISABLE=1 tar -zcf #{basename} #{basename[0..-8]}"
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
        tarballs = FileList['spec/fixtures/**/*.tar.gz']
        tarballs.each do |tarball|
          basename = File.basename(tarball)
          Dir.chdir(File.dirname(tarball)) do
            sh "rm -rf #{basename[0..-8]} && tar zxf #{basename}"
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
      if `which hg` && !$?.success?
        puts red('[!] Mercurial (`hg`) must be installed to rebuild the integration fixtures.')
        exit 1
      end
      title 'Running Integration tests'
      sh 'rm -rf spec/cocoapods-integration-specs/tmp'
      title 'Building all the fixtures'
      sh('bundle exec bacon spec/integration.rb') {}
      title 'Storing fixtures'
      # Copy the files to the files produced by the specs to the after folders
      FileList['tmp/*'].each do |source|
        destination = "spec/cocoapods-integration-specs/#{source.gsub('tmp/', '')}/after"
        if File.exist?(destination)
          sh "rm -rf #{destination}"
          sh "mv #{source} #{destination}"
        end
      end

      # Remove files not used for the comparison
      # To keep the git diff clean
      files_to_delete = FileList['spec/cocoapods-integration-specs/*/after/{Podfile,*.podspec,**/*.xcodeproj,PodTest-hg-source}', '.DS_Store']
      files_to_delete.exclude('/spec/cocoapods-integration-specs/init_single_platform/**/*.*')
      files_to_delete.each do |file_to_delete|
        sh "rm -rf #{file_to_delete}"
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
      examples.each do |example|
        Dir.chdir(example.to_s) do
          # TODO: we need to open the workspace in Xcode at least once, otherwise it might not contain schemes.
          # The schemes do not seem to survive a SCM round-trip.
          sh "open '#{example.basename}.xcworkspace'"
          sleep 5
        end
      end
    end

    desc 'Build all examples'
    task :build do
      Bundler.require 'xcodeproj', :development
      Dir['examples/*'].each do |dir|
        Dir.chdir(dir) do
          next if dir == 'examples/watchOS Example'
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
            puts "    Building scheme: #{scheme_name}"

            project = Xcodeproj::Project.open(project_path)
            target = project.targets.first

            case target
            when :osx
              execute_command "xcodebuild -workspace '#{workspace_path}' -scheme '#{scheme_name}' clean build"
            when :ios
              xcode_version = `xcodebuild -version`.scan(/Xcode (.*)\n/).first.first
              major_version = xcode_version.split('.').first.to_i
              # Specifically build against the simulator SDK so we don't have to deal with code signing.
              simulator_name = major_version > 5 ? 'iPhone 6' : 'iPhone Retina (4-inch)'
              execute_command "xcodebuild -workspace '#{workspace_path}' -scheme '#{scheme_name}' clean build ONLY_ACTIVE_ARCH=NO -destination 'platform=iOS Simulator,name=#{simulator_name}"
            end
          end
        end
      end
    end
  end

  #-----------------------------------------------------------------------------#

  desc 'Run all specs'
  task :spec => 'spec:all'

  task :default => :spec

  #-- Rubocop ----------------------------------------------------------------#

  desc 'Check code against RuboCop rules'
  task :rubocop do
    sh 'bundle exec rubocop lib spec Rakefile'
  end

  #-- Inch -------------------------------------------------------------------#

  namespace :inch do
    desc 'Lint the completeness of the documentation with Inch'
    task :spec do
      require 'inch'
      require 'inch/cli'

      puts 'Parse docs …'
      YARD::Parser::SourceParser.before_parse_file do |_|
        print green('.') # Visualize progress
      end

      class ProgressEnumerable
        include Enumerable

        def initialize(array)
          @array = array
        end

        def each
          @array.each do |e|
            print '.'
            yield e
          end
        end
      end

      Inch::Codebase::Objects.class_eval do
        alias_method :old_init, :initialize
        def initialize(language, objects)
          puts "\n\nEvaluating …"
          old_init(language, ProgressEnumerable.new(objects))
        end
      end

      codebase = Inch::Codebase.parse(Dir.pwd, Inch::Config.codebase)
      context = Inch::API::List.new(codebase, {})
      options = Inch::CLI::Command::Options::List.new
      options.show_all = true
      options.ui = Inch::Utils::UI.new
      failing_grade_symbols = [:B, :C] # add :U for undocumented
      failing_grade_list = context.grade_lists.select { |g| failing_grade_symbols.include?(g.to_sym) }
      Inch::CLI::Command::Output::List.new(options, context.objects, failing_grade_list)
      puts
      if context.objects.any? { |o| failing_grade_symbols.include?(o.grade.to_sym) }
        puts red('✗ Lint of Documentation failed: Please improve above suggestions.')
        exit 1
      else
        puts green('✓ Nothing to improve detected.')
      end
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
