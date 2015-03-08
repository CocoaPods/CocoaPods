
# ------------------------------------ #
#  CocoaPods Integration tests         #
# ------------------------------------ #

#-----------------------------------------------------------------------------#

# The following integrations tests are based on file comparison.
#
# 1.  For each test there is a folder with a `before` and `after` subfolders.
# 2.  The contents of the before folder are copied to the `TMP_DIR` folder and
#     then the given arguments are passed to the `POD_BINARY`.
# 3.  After the pod command completes the execution the each file in the
#     `after` subfolder is compared to be to the contents of the temporary
#     directory.  If the contents of the file do not match an error is
#     registered. Xcode projects are compared in an UUID agnostic way.
#
# Notes:
#
# - The output of the pod command is saved in the `execution_output.txt` file
#   which should be added to the `after` folder to test the CocoaPods UI.
# - To create a new test, just create a before folder with the environment to
#   test, copy it to the after folder and run the tested pod command inside.
#   Then just add the tests below this files with the name of the folder and
#   the arguments.
#
# Rationale:
#
# - Have a way to track precisely the evolution of the artifacts (and of the
#   UI) produced by CocoaPods (git diff of the after folders).
# - Allow uses to submit pull requests with the environment necessary to
#   reproduce an issue.
# - Have robust tests which don't depend on the programmatic interface of
#   CocoaPods. These tests depend only the binary and its arguments an thus are
#   suitable for testing CP regardless of the implementation (they could even
#   work for an Objective-C one)

#-----------------------------------------------------------------------------#

# @return [Pathname] The root of the repo.
#
ROOT = Pathname.new(File.expand_path('../../', __FILE__)) unless defined? ROOT
$:.unshift((ROOT + 'spec').to_s)

require 'rubygems'
require 'bundler/setup'
require 'pretty_bacon'
require 'colored'
require 'clintegracon'
require 'integration/xcodeproj_project_yaml'
require 'tmpdir'

CLIntegracon.configure do |c|
  c.spec_path = ROOT + 'spec/cocoapods-integration-specs'
  c.temp_path = ROOT + 'tmp'

  # Transform produced project files to YAMLs
  c.transform_produced '**/*.xcodeproj' do |path|
    # Creates a YAML representation of the Xcodeproj files
    # which should be used as a reference for comparison.
    xcodeproj = Xcodeproj::Project.open(path)
    File.open("#{path}.yaml", 'w') do |file|
      file.write xcodeproj.to_yaml
    end
  end

  # Register special handling for YAML files
  paths = [/Podfile\.lock/, /Manifest\.lock$/, /xcodeproj\.yaml$/]
  c.has_special_handling_for(*paths) do |path|
    # Remove CocoaPods version
    yaml = File.open(path) { |f| YAML.load(f) }
    yaml.delete('COCOAPODS')
    YAML.dump(yaml)
  end

  # So we don't need to compare them directly
  c.ignores /\.xcodeproj\//
  c.ignores 'Podfile'

  # Ignore certain OSX files
  c.ignores '.DS_Store'

  # Ignore xcuserdata
  c.ignores %r{/xcuserdata/}

  # Needed for some test cases
  c.ignores 'Reachability.podspec'
  c.ignores 'PodTest-hg-source/**'

  c.hook_into :bacon
end

describe_cli 'pod' do
  Process.wait(spawn('which hg', :err => :out, :out => '/dev/null'))
  has_mercurial = $?.success?

  subject do |s|
    s.executable = "ruby #{ROOT + 'bin/pod'}"
    s.environment_vars = {
      'CP_REPOS_DIR'             => ROOT + 'spec/fixtures/spec-repos',
      'CP_AGGRESSIVE_CACHE'      => 'TRUE',
      'XCODEPROJ_DISABLE_XCPROJ' => 'TRUE',
      'CLAIDE_DISABLE_AUTO_WRAP' => 'TRUE',
    }
    s.default_args = [
      '--verbose',
      '--no-ansi',
    ]
    s.replace_path ROOT.to_s, 'ROOT'
    s.replace_path `which git`.chomp, 'GIT_BIN'
    s.replace_path `which hg`.chomp, 'HG_BIN' if has_mercurial
    s.replace_user_path 'Library/Caches/CocoaPods', 'CACHES_DIR'
    s.replace_pattern %r{#{Dir.tmpdir}/[a-zA-Z0-9-]+}, 'TMPDIR'
    s.replace_pattern /\d{4}-\d\d-\d\d \d\d:\d\d:\d\d [-+]\d{4}/, '<#DATE#>'
    s.replace_pattern /\(Took \d+.\d+ seconds\)/, '(Took <#DURATION#> seconds)'
  end

  describe 'Pod install' do
    # Test installation with no integration
    # Test subspecs inheritance

    describe 'Integrates a project with CocoaPods' do
      behaves_like cli_spec 'install_new',
                            'install --no-repo-update'
    end

    describe 'Adds a Pod to an existing installation' do
      behaves_like cli_spec 'install_add_pod',
                            'install --no-repo-update'
    end

    describe 'Removes a Pod from an existing installation' do
      behaves_like cli_spec 'install_remove_pod',
                            'install --no-repo-update'
    end

    describe 'Creates an installation with multiple target definitions' do
      behaves_like cli_spec 'install_multiple_targets',
                            'install --no-repo-update'
    end

    description = 'Installs a Pod with different subspecs activated across different targets'
    if has_mercurial
      describe description do
        behaves_like cli_spec 'install_subspecs',
                              'install --no-repo-update'
      end
    else
      Bacon::ErrorLog << "[!] Skipping test due to missing `hg` executable: #{description}".red << "\n\n"
    end

    describe 'Installs a Pod with subspecs and does not duplicate the prefix header' do
      behaves_like cli_spec 'install_subspecs_no_duplicate_prefix',
                            'install --no-repo-update'
    end

    describe 'Installs a Pod with a local source' do
      behaves_like cli_spec 'install_local_source',
                            'install --no-repo-update'
    end

    description = 'Installs a Pod with an external source'
    if has_mercurial
      describe description do
        behaves_like cli_spec 'install_external_source',
                              'install --no-repo-update'
      end
    else
      Bacon::ErrorLog << "[!] Skipping test due to missing `hg` executable: #{description}".red << "\n\n"
    end

    describe 'Installs a Pod given the podspec' do
      behaves_like cli_spec 'install_podspec',
                            'install --no-repo-update'
    end

    describe 'Performs an installation using a custom workspace' do
      behaves_like cli_spec 'install_custom_workspace',
                            'install --no-repo-update'
    end

    describe 'Integrates a target with custom build settings' do
      behaves_like cli_spec 'install_custom_build_configuration',
                            'install --no-repo-update'
    end

    describe 'Integrates a Pod with resources' do
      behaves_like cli_spec 'install_resources',
                            'install --no-repo-update'
    end

    describe 'Integrates a Pod without source files but with resources' do
      behaves_like cli_spec 'install_resources_no_source_files',
                            'install --no-repo-update'
    end

    describe 'Integrates a Pod using frameworks with resources' do
      behaves_like cli_spec 'install_framework_resources',
                            'install --no-repo-update'
    end

    # @todo add tests for all the hooks API
    #
    describe 'Runs the Podfile callbacks' do
      behaves_like cli_spec 'install_podfile_callbacks',
                            'install --no-repo-update'
    end

    describe 'Uses Lockfile checkout options' do
      behaves_like cli_spec 'install_using_checkout_options',
                            'install --no-repo-update'
    end
  end

  #--------------------------------------#

  describe 'Pod update' do
    describe 'Updates an existing installation' do
      behaves_like cli_spec 'update_all',
                            'update --no-repo-update'
    end

    describe 'Updates a selected Pod in an existing installation' do
      behaves_like cli_spec 'update_selected',
                            'update Reachability --no-repo-update'
    end
  end

  #--------------------------------------#

  describe 'Pod lint' do
    describe 'Lints a Pod' do
      behaves_like cli_spec 'spec_lint',
                            'spec lint --quick'
    end
  end

  #--------------------------------------#

  describe 'Pod init' do
    describe 'Initializes a Podfile with a single platform' do
      behaves_like cli_spec 'init_single_platform',
                            'init'
    end
  end

  #--------------------------------------#
end
