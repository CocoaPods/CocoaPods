
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

# The spec helper is not required on purpose to keep those tests segregated.
# It would also create issues because it clears the temp folder before every
# requirement (`it` call).

require 'pathname'

# @return [Pathname] The root of the repo.
#
ROOT = Pathname.new(File.expand_path('../../', __FILE__)) unless defined? ROOT

require 'rubygems'
require 'bundler/setup'
require 'pretty_bacon'
require 'colored'
require 'diffy'
require 'xcodeproj' # For Differ

# @return [Pathname The folder where the CocoaPods binary should operate.
#
TMP_DIR = ROOT + 'tmp' unless defined? TMP_DIR

# @return [String] The CocoaPods binary to use for the tests.
#
POD_BINARY = "ruby " + ROOT.to_s + '/bin/pod' unless defined? POD_BINARY

#-----------------------------------------------------------------------------#

# @!group Helpers

# Copies the before subdirectory of the given tests folder in the temporary
# directory.
#
# @param  [String] folder
#         the name of the folder of the tests.
#
def copy_files(folder)
  source = File.expand_path("../cocoapods-integration-specs/#{folder}/before", __FILE__)
  destination = TMP_DIR + folder
  destination.mkpath
  FileUtils.cp_r(Dir.glob("#{source}/*"), destination)
end

# Runs the Pod executable with the given arguments in the temporary directory.
#
# @param  [String] arguments
#         the arguments to pass to the CocoaPods binary.
#
# @note   If the pod binary is called with the ruby executable it requires
#         bundler ensuring that the execution is performed in the correct
#         environment.
#
def launch_binary(arguments, folder)
  command = "CP_AGGRESSIVE_CACHE=TRUE #{POD_BINARY} #{arguments} --verbose --no-ansi 2>&1"
  Dir.chdir(TMP_DIR + folder) do
    output = `#{command}`
    it "$ pod #{arguments}" do
      $?.should.satisfy("Pod binary failed\n\n#{output}") do
        $?.success?
      end
    end

    File.open('execution_output.txt', 'w') do |file|
      file.write(command.gsub(POD_BINARY, '$ pod'))
      file.write(output.gsub(ROOT.to_s, 'ROOT').gsub(%r[/Users/.*/Library/Caches/CocoaPods/],"CACHES_DIR/"))
    end
  end
  $?.success?
end

# Creates a YAML representation of the Xcodeproj files which should be used as
# a reference.
#
def run_post_execution_actions(folder)
  Dir.glob("#{TMP_DIR + folder}/**/*.xcodeproj") do |project_path|
    xcodeproj = Xcodeproj::Project.open(project_path)
    require 'yaml'
    pretty_print = xcodeproj.pretty_print
    sections = []
    sorted_keys = ['File References', 'Targets', 'Build Configurations']
    sorted_keys.each do |key|
      yaml =  { key => pretty_print[key]}.to_yaml
      sections << yaml
    end
    file_contents = (sections * "\n\n").gsub!("---",'')
    File.open("#{project_path}.yaml", 'w') do |file|
      file.write(file_contents)
    end
  end
end

# Creates a requirement which compares every file in the after folder with the
# artifacts created by the pod executable in the temporary directory according
# to its file type.
#
# @param  [String] folder
#         the name of the folder of the tests.
#
def check_with_folder(folder)
  source = File.expand_path("../cocoapods-integration-specs/#{folder}", __FILE__)
  Dir.glob("#{source}/after/**/*") do |expected_path|
    next unless File.file?(expected_path)
    relative_path = expected_path.gsub("#{source}/after/", '')
    expected = Pathname.new(expected_path)
    produced = TMP_DIR + folder + relative_path

      case expected_path
      when %r[/xcuserdata/], %r[\.pbxproj$]
        # Projects are compared through the more readable yaml representation
        next
      when %r[execution_output.txt$]
        # TODO The output from the caches changes on Travis
        next
      end

      it relative_path do
        file_should_exist(produced)
        case expected_path
        when %r[Podfile\.lock$], %r[Manifest\.lock$], %r[xcodeproj\.yaml$]
          yaml_should_match(expected, produced)
        else
          file_should_match(expected, produced)
        end
      end
  end
end

#--------------------------------------#

# @!group File Comparisons

# Checks that the file exits.
#
# @param [Pathname] file
#        The file to check.
#
def file_should_exist(file)
  file.should.exist?
end

# Compares two lockfiles because CocoaPods 0.16 doesn't oder them in 1.8.7.
#
# @param [Pathname] expected
#        The reference in the `after` folder.
#
# @param [Pathname] produced
#        The file in the temporary directory after running the pod command.
#
def yaml_should_match(expected, produced)
  expected_yaml = File.open(expected) { |f| YAML.load(f) }
  produced_yaml = File.open(produced) { |f| YAML.load(f) }
  # Remove CocoaPods version
  expected_yaml.delete('COCOAPODS')
  produced_yaml.delete('COCOAPODS')
  desc = []
  desc << "YAML comparison error `#{expected}`"

  desc << ("--- YAML DIFF " << "-" * 65)
  diffy_diff = ''
  Diffy::Diff.new(expected.to_s, produced.to_s, :source => 'files', :context => 3).each do |line|
    case line
    when /^\+/ then diffy_diff << line.green
    when /^-/ then diffy_diff << line.red
    else diffy_diff << line
    end
  end
  desc << diffy_diff

  desc << ("--- XCODEPROJ DIFF " << "-" * 60)
  diff_options = {:key_1 => "$produced", :key_2 => "$expected"}
  diff = Xcodeproj::Differ.diff(produced_yaml, expected_yaml, diff_options).to_yaml
  diff.gsub!("$produced", "produced".green)
  diff.gsub!("$expected", "expected".red)
  desc << diff
  desc << ("--- END " << "-" * 70)

  expected_yaml.should.satisfy(desc * "\n\n") do
    if RUBY_VERSION < "1.9"
      true # CP is not sorting array derived from hashes whose order is
           # undefined in 1.8.7
    else
      expected_yaml == produced_yaml
    end
  end
end

# Compares two Xcode projects in an UUID insensitive fashion and producing a
# clear diff to highlight the differences.
#
# @param [Pathname] expected @see #yaml_should_match
# @param [Pathname] produced @see #yaml_should_match
#
# def xcodeproj_should_match(expected, produced)
#   expected_proj = Xcodeproj::Project.open(expected + '..')
#   produced_proj = Xcodeproj::Project.open(produced + '..')
#   diff = produced_proj.to_tree_hash.recursive_diff(expected_proj.to_tree_hash, "#produced#", "#reference#")
#   desc = "Project comparison error `#{expected}`"
#   if diff
#     desc << "\n\n#{diff.inspect.cyan}"
#     pretty_yaml = diff.to_yaml
#     pretty_yaml = pretty_yaml.gsub(/['"]#produced#['"]/,'produced'.cyan)
#     pretty_yaml = pretty_yaml.gsub(/['"]#reference#['"]/,'reference'.magenta)
#     desc << "\n\n#{pretty_yaml}"
#   end
#   diff.should.satisfy(desc) do |diff|
#     diff.nil?
#   end
# end

# Compares two files to check if they are identical and produces a clear diff
# to highlight the differences.
#
# @param [Pathname] expected @see #yaml_should_match
# @param [Pathname] produced @see #yaml_should_match
#
def file_should_match(expected, produced)
  is_equal = FileUtils.compare_file(expected, produced)
  description = []
  description << "File comparison error `#{expected}`"
  description << ""
  description << ("--- DIFF " << "-" * 70)
  Diffy::Diff.new(expected.to_s, produced.to_s, :source => 'files', :context => 3).each do |line|
    case line
    when /^\+/ then description << line.gsub("\n",'').green
    when /^-/ then description << line.gsub("\n",'').red
    else description << line.gsub("\n",'')
    end
  end
  description << ("--- END " << "-" * 70)
  description << ""
  is_equal.should.satisfy(description * "\n") do
    is_equal == true
  end
end

#-----------------------------------------------------------------------------#

# @!group Description implementation

# Performs the checks for the test with the given folder using the given
# arguments.
#
# @param [String] arguments
#        The arguments to pass to the Pod executable.
#
# @param [String] folder
#        The name of the folder which contains the `before` and `after`
#        subfolders.
#
def check(arguments, folder)
  focused_check(arguments, folder)
end

# Shortcut to focus on a test: Comment the implementation of #check and
# call this from the relevant test.
#
def focused_check(arguments, folder)
  copy_files(folder)
  executed = launch_binary(arguments, folder)
  run_post_execution_actions(folder)
  check_with_folder(folder) if executed
end

#-----------------------------------------------------------------------------#

describe "Integration" do
  TMP_DIR.rmtree if TMP_DIR.exist?
  TMP_DIR.mkpath

  describe "Pod install" do

    # Test installation with no integration
    # Test subspecs inheritance

    describe "Integrates a project with CocoaPods" do
      check "install --no-repo-update", "install_new"
    end

    describe "Adds a Pod to an existing installation" do
      check "install --no-repo-update", "install_add_pod"
    end

    describe "Removes a Pod from an existing installation" do
      check "install --no-repo-update", "install_remove_pod"
    end

    describe "Creates an installation with multiple target definitions" do
      check "install --no-repo-update", "install_multiple_targets"
    end

    describe "Installs a Pod with different subspecs activated across different targets" do
      check "install --no-repo-update", "install_subspecs"
    end

    describe "Installs a Pod with subspecs and does not duplicate the prefix header" do
      check "install --no-repo-update", "install_subspecs_no_duplicate_prefix"
    end

    describe "Installs a Pod with a local source" do
      check "install --no-repo-update", "install_local_source"
    end

    describe "Installs a Pod with an external source" do
      check "install --no-repo-update", "install_external_source"
    end

    describe "Installs a Pod given the podspec" do
      check "install --no-repo-update", "install_podspec"
    end

    describe "Performs an installation using a custom workspace" do
      check "install --no-repo-update", "install_custom_workspace"
    end

    describe "Integrates a target with custom build settings" do
      check "install --no-repo-update", "install_custom_build_configuration"
    end

    # @todo add tests for all the hooks API
    #
    describe "Runs the Podfile callbacks" do
      check "install --no-repo-update", "install_podfile_callbacks"
    end

    # @todo add tests for all the hooks API
    #
    describe "Runs the specification callbacks" do
      check "install --no-repo-update", "install_spec_callbacks"
    end

  end

  #--------------------------------------#

  describe "Pod update" do

    describe "Updates an existing installation" do
      check "update --no-repo-update", "update_all"
    end

    describe "Updates a selected Pod in an existing installation" do
      check "update Reachability --no-repo-update", "update_selected"
    end

  end

  #--------------------------------------#

  describe "Pod lint" do

    describe "Lints a Pod" do
      check "spec lint --quick", "spec_lint"
    end

  end

  #--------------------------------------#

  describe "Pod init" do

    describe "Initializes a Podfile with a single platform" do
      check "init", "init_single_platform"
    end

  end

  #--------------------------------------#

end
