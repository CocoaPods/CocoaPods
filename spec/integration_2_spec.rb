
# ------------------------------------ #
#  CocoaPods Integration tests take 2  #
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
ROOT = Pathname.new(File.expand_path('../../', __FILE__))
TMP_DIR = ROOT + 'tmp'
POD_BINARY = "ruby " + ROOT.to_s + '/bin/pod' unless defined? POD_BINARY

$:.unshift((ROOT + 'spec').to_s)
require 'spec_helper/bacon'
require 'colored'
require 'diffy'
require 'Xcodeproj'

#-----------------------------------------------------------------------------#


# @!group Description implementation

def check(arguments, folder)
  copy_files(folder)
  launch_binary(arguments)
  check_with_folder(folder)
end

#--------------------------------------#

# @!group Helpers

# Copies the before subdirectory of the given tests folder in the temporary
# directory.
#
# @param  [String] folder
#         the name of the folder of the tests.
#
def copy_files(folder)
  if TMP_DIR.exist?
    TMP_DIR.rmtree
    TMP_DIR.mkpath
  end

  source = File.expand_path("../integration/#{folder}/before", __FILE__)
  FileUtils.cp_r(Dir.glob("#{source}/*"), TMP_DIR)
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
def launch_binary(arguments)
  # TODO CP 0.16 doesn't offer the possibility to skip just the installation
  # of the docs.
  command = "#{POD_BINARY} #{arguments} --verbose --no-color"
  Dir.chdir(TMP_DIR) do
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
end

# Creates a requirement which compares every file in the after folder with the
# artifacts created by the pod executable in the temporary directory according
# to its file type.
#
# @param  [String] folder
#         the name of the folder of the tests.
#
def check_with_folder(folder)
  source = File.expand_path("../integration/#{folder}", __FILE__)
  Dir.glob("#{source}/after/**/*") do |expected|
    next unless File.file?(expected)
    relative_path = expected.gsub("#{source}/after/", '')
    produced = TMP_DIR + relative_path

    case expected
    when %r[/xcuserdata/]
      # skip
    when %r[Podfile\.lock$]
      compare_lockfile(expected, produced, relative_path)
    when %r[\.pbxproj$]
      compare_xcodeproj(expected, produced, relative_path)
    else
      compare_generic(expected, produced, relative_path)
    end
  end
end

#--------------------------------------#

# @!group File Comparisons

# Compares two lockfiles because CocoaPods 0.16 doesn't oder them in 1.8.7.
#
def compare_lockfile(expected, produced, relative_path)
  expected_yaml = YAML::load(File.open(expected))
  produced_yaml = YAML::load(File.open(produced))
  desc = "Lockfile comparison error `#{relative_path}`"
  desc << "\n EXPECTED:\n#{expected_yaml}\n"
  desc << "\n PRODUCED:\n#{produced_yaml}\n"
  it relative_path do
    expected_yaml.should.satisfy(desc) do |expected_yaml|
      expected_yaml == produced_yaml
    end
  end
end

# Compares two Xcode projects in an UUID insensitive fashion and producing a
# clear diff to highlight the differences.
#
def compare_xcodeproj(expected, produced, relative_path)
  expected_proj = Xcodeproj::Project.new(expected.gsub('project.pbxproj',''))
  produced_proj = Xcodeproj::Project.new(produced.to_s.gsub('project.pbxproj',''))
  diff = produced_proj.to_tree_hash.recursive_diff(expected_proj.to_tree_hash, "#produced#", "#reference#")
  desc = "Project comparison error `#{relative_path}`"
  if diff
    desc << "\n#{diff.to_yaml.gsub('"#produced#"','produced'.red).gsub('"#reference#"','reference'.yellow)}"
  end
  it relative_path do
    diff.should.satisfy(desc) do |diff|
      diff.nil?
    end
  end
end

# Compares two files to check if they are identical and produces a clear diff
# to highlight the differences.
#
def compare_generic(expected, produced, relative_path)
  is_equal = FileUtils.compare_file(expected, produced)
  it relative_path do
    description = []
    description << "File comparison error `#{relative_path}`"
    description << produced
    description << expected
    description << ""
    description << ("--- DIFF " << "-" * 70)
    Diffy::Diff.new(expected.to_s, produced.to_s, :source => 'files', :context => 3).each do |line|
      case line
      when /^\+/ then description << line.gsub("\n",'').green
      when /^-/ then description << line.gsub("\n",'').red
      else description << line.gsub("\n",'')
      end
    end
    description << ("--- DIFF " << "-" * 70)
    description << ""
    is_equal.should.satisfy(description * "\n") do |is_equal|
      is_equal == true
    end
  end
end

#-----------------------------------------------------------------------------#


describe "Integration take 2" do

  describe "Pod install" do

    describe "Integrates a project with CocoaPods" do
      check "install --no-update --no-doc", "install_new"
    end

    describe "Adds a Pod to an existing installation" do
      check "install --no-update --no-doc", "install_add_pod"
    end

    describe "Removes a Pod from an existing installation" do
      check "install --no-update --no-doc", "install_add_pod"
    end

    # describe "Creates an installation with multiple target definitions" do
      # check "install", "multiple_targets"
    # end

    # describe "Runs the Podfile callbacks" do
    # check "update", "podfile_callbacks"
    # end

    # describe "Runs the specification callbacks" do
    # check "update", "specification_callbacks"
    # end

    # describe "Generates the documentation of Pod during installation" do
    # # TODO: requires CocoaPods 0.17
    # check "update", "installation_update"
    # end

    # describe "Installs a Pod with different subspecs activated across different targets" do
    # check "update", "subspecs"
    # end

    # describe "Installs a Pod with a local source" do
    # check "update", "podfile_local_pod"
    # end

    # describe "Installs a Pod with an external source" do
    # check "update", "podfile_external_source"
    # end

    # describe "Installs a Pod given the podspec" do
    # check "update", "podfile_podspec"
    # end

  end

  #--------------------------------------#

  describe "Pod update" do

    describe "Updates an existing installation" do
      check "update --no-update", "update"
    end

  end

  #--------------------------------------#

  describe "Pod lint" do

    describe "Lints a Pod" do
      check "spec lint --quick", "spec_lint"
    end

  end

  #--------------------------------------#

end


