
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
# - Allow users to submit pull requests with the environment necessary to
#   reproduce an issue.
# - Have robust tests which don't depend on the programmatic interface of
#   CocoaPods. These tests depend only the binary and its arguments and thus are
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
require 'CLIntegracon'

require 'cocoapods-core/lockfile'
require 'cocoapods-core/yaml_helper'
require 'fileutils'
require 'integration/file_tree'
require 'integration/xcodeproj_project_yaml'
require 'tmpdir'

if (developer_bin = `xcode-select -p 2>/dev/null`.strip) && $?.success?
  developer_bin = Pathname(developer_bin) + 'usr/bin'
  ENV['PATH'] = "#{developer_bin}#{File::PATH_SEPARATOR}#{ENV['PATH']}"
end

CLIntegracon.configure do |c|
  c.spec_path = ROOT + 'spec/cocoapods-integration-specs'
  c.temp_path = ROOT + 'tmp'

  # Transform produced project files to YAMLs
  c.transform_produced '**/*.xcodeproj' do |path|
    # Creates a YAML representation of the Xcodeproj files
    # which should be used as a reference for comparison.
    xcodeproj = Xcodeproj::Project.open(path)
    yaml = xcodeproj.to_yaml
    path.rmtree
    path.open('w') { |f| f << yaml }
  end

  c.transform_produced '**/*.framework' do |path|
    tree = FileTree.to_tree(path)
    path.rmtree
    path.open('w') { |f| f << tree }
  end

  # Register special handling for YAML files
  c.transform_produced %r{(^|/)(Podfile|Manifest).lock$} do |path|
    # Remove CocoaPods version & Podfile checksum
    yaml = YAML.load(path.read)
    deleted_keys = ['COCOAPODS', 'PODFILE CHECKSUM']
    deleted_keys.each { |key| yaml.delete(key) }
    keys_hint = Pod::Lockfile::HASH_KEY_ORDER - deleted_keys
    path.open('w') { |f| f << Pod::YAMLHelper.convert_hash(yaml, keys_hint, "\n\n") }
  end

  c.preprocess('**/*.xcodeproj', %r{(^|/)(Podfile|Manifest).lock$}) do |path|
    keys_hint = if path.extname == '.lock'
                  Pod::Lockfile::HASH_KEY_ORDER
                end
    contents = path.read
    if contents.strip.empty?
      contents
    else
      Pod::YAMLHelper.convert_hash(YAML.load(contents), keys_hint, "\n\n")
    end
  end

  # So we don't need to compare them directly
  c.ignores 'Podfile'

  # Ignore certain OSX files
  c.ignores '.DS_Store'

  # Ignore xcuserdata
  c.ignores %r{/xcuserdata/}

  # Needed for some test cases
  c.ignores '*.podspec'
  c.ignores 'PodTest-hg-source/**/*'

  c.hook_into :bacon
end

describe_cli 'pod' do
  Process.wait(spawn('which hg', :err => :out, :out => '/dev/null'))
  has_mercurial = $?.success?

  subject do |s|
    s.executable = "ruby #{ROOT + 'bin/pod'}"
    s.environment_vars = {
      'CLAIDE_DISABLE_AUTO_WRAP'            => 'TRUE',
      'COCOAPODS_DISABLE_STATS'             => 'TRUE',
      'COCOAPODS_SKIP_CACHE'                => 'TRUE',
      'COCOAPODS_VALIDATOR_SKIP_XCODEBUILD' => 'TRUE',
      'CP_REPOS_DIR'                        => ROOT + 'spec/fixtures/spec-repos',
    }
    s.default_args = [
      '--verbose',
      '--no-ansi',
    ]
    s.replace_path %r{#{CLIntegracon.shared_config.temp_path}/\w+/transformed}, 'PROJECT'
    s.replace_path ROOT.to_s, 'ROOT'
    s.replace_path `which git`.chomp, 'GIT_BIN'
    s.replace_path `which hg`.chomp, 'HG_BIN' if has_mercurial
    s.replace_path `which bash`.chomp, 'BASH_BIN'
    s.replace_path `which curl`.chomp, 'CURL_BIN'
    s.replace_user_path 'Library/Caches/CocoaPods', 'CACHES_DIR'
    s.replace_pattern /#{Dir.tmpdir}\/[\w-]+/io, 'TMPDIR'
    s.replace_pattern /\d{4}-\d\d-\d\d \d\d:\d\d:\d\d [-+]\d{4}/, '<#DATE#>'
    s.replace_pattern /\(Took \d+.\d+ seconds\)/, '(Took <#DURATION#> seconds)'

    # This was changed in a very recent git version
    s.replace_pattern /git checkout -b <new-branch-name>/, 'git checkout -b new_branch_name'

    # git sometimes prints this, but not always ¯\_(ツ)_/¯
    s.replace_pattern /^\s*Checking out files.*done\./, ''

    s.replace_path %r{
      `[^`]*? # The opening backtick on a plugin path
      ([[[:alnum:]]_+-]+?) # The plugin name
      (- ([[:xdigit:]]+ | #{Gem::Version::VERSION_PATTERN}))? # The version or SHA
      /lib/cocoapods_plugin.rb # The actual plugin file that gets loaded
    }iox, '`\1/lib/cocoapods_plugin.rb'

    s.replace_pattern %r{
      ^(\s* \$ \s (CURL_BIN | #{`which curl`.strip}) .* \n)
      ^\s* % \s* Total .* \n
      ^\s* Dload \s* Upload .* \n
      (^\s* [[:cntrl:]] .* \n)+
    }iox, "\\1\n"
  end

  describe 'Pod install' do
    # Test installation with no integration
    # Test subspecs inheritance

    #--------------------------------------#

    describe 'Pod init' do
      describe 'Initializes a Podfile with a single platform' do
        behaves_like cli_spec 'init_single_platform',
                              'init'
      end
    end

    #--------------------------------------#

    describe 'Integrates a project with an empty Podfile with CocoaPods' do
      behaves_like cli_spec 'install_no_dependencies',
                            'install --no-repo-update'
    end

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

    describe 'Installs a Pod with a custom module map' do
      behaves_like cli_spec 'install_custom_module_map',
                            'install --no-repo-update'
    end

    describe 'Installs a Pod with a custom module name' do
      behaves_like cli_spec 'install_custom_module_name',
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

    describe 'Integrates a Pod using non Objective-C source files' do
      behaves_like cli_spec 'install_non_objective_c_files',
                            'install --no-repo-update'
    end

    describe 'Integrates a Pod using a dynamic vendored framework' do
      # We have to disable verbose mode by adding --no-verbose here,
      # otherwise curl output is included in execution output.
      behaves_like cli_spec 'install_vendored_dynamic_framework',
                            'install --no-repo-update --no-verbose'
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

    describe 'Integrates a pod with search paths inheritance' do
      behaves_like cli_spec 'install_search_paths_inheritance',
                            'install --no-repo-update'
    end

    describe 'Integrates a Pod with circular subspec dependencies' do
      behaves_like cli_spec 'install_circular_subspec_dependency',
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
    describe 'Lints a Pod from source with a prepare_command' do
      # We have to disable verbose mode by adding --no-verbose here,
      # otherwise xcodebuild output is included in execution output.
      behaves_like cli_spec 'lib_lint_with_prepare_command',
                            'lib lint',
                            '--no-verbose'
    end

    describe 'Lints a Pod' do
      behaves_like cli_spec 'spec_lint',
                            'spec lint --quick'
    end

    describe 'Lints a remote Pod' do
      spec_url = 'https://github.com/CocoaPods/Specs/raw/master/Specs/A2DynamicDelegate/2.0.2/A2DynamicDelegate.podspec.json'
      behaves_like cli_spec 'spec_lint_remote',
                            "spec lint --quick --allow-warnings --silent #{spec_url}"
    end
  end

  #--------------------------------------#
end
