module SpecHelper
  def self.tmp_repos_path
    TemporaryRepos.tmp_repos_path
  end

  module TemporaryRepos
    extend Pod::Executable
    executable :git

    # @return [Pathname] The path for the repo with the given name.
    #
    def repo_path(name)
      tmp_repos_path + name
    end

    # Makes a repo with the given name.
    #
    def repo_make(name)
      path = repo_path(name)
      path.mkpath
      Dir.chdir(path) do
        Pod::Executable.capture_command!('git', %w(init))
        repo_make_readme_change(name, 'Added')
        Pod::Executable.capture_command!('git', %w(add .))
        Pod::Executable.capture_command!('git', %w(commit -nm Initialized.))
      end
      path
    end

    # Clones a repo to the given name.
    #
    def repo_clone(from_name, to_name)
      Dir.chdir(tmp_repos_path) { Pod::Executable.capture_command!('git', %W(clone #{from_name} -- #{to_name})) }
      repo_path(to_name)
    end

    def repo_make_readme_change(name, string)
      file = repo_path(name) + 'README'
      file.open('w') { |f| f << "#{string}" }
    end

    #--------------------------------------#

    def test_repo_path
      repo_path('master')
    end

    # Sets up a lighweight master repo in `tmp/cocoapods/repos/master` with the
    # contents of `spec/fixtures/spec-repos/test_repo`.
    #
    def set_up_test_repo
      require 'fileutils'
      test_repo_path.mkpath
      origin = ROOT + 'spec/fixtures/spec-repos/test_repo/.'
      destination = tmp_repos_path + 'master'
      FileUtils.cp_r(origin, destination)
      FileUtils.rm_r(destination + './.git')
      repo_make('master')
    end

    def test_old_repo_path
      repo_path('../master')
    end

    # Sets up a lighweight master repo in `tmp/cocoapods/master` with the
    # contents of `spec/fixtures/spec-repos/test_repo`.
    #
    def set_up_old_test_repo
      require 'fileutils'
      test_old_repo_path.mkpath
      origin = ROOT + 'spec/fixtures/spec-repos/test_repo/.'
      destination = tmp_repos_path + '../master'
      FileUtils.cp_r(origin, destination)
      FileUtils.rm_r(destination + './.git')
      repo_make('../master')
    end

    #--------------------------------------#

    def tmp_repos_path
      TemporaryRepos.tmp_repos_path
    end

    def self.tmp_repos_path
      SpecHelper.temporary_directory + 'cocoapods/repos'
    end

    def self.extended(base)
      # Make Context methods available
      # WORKAROUND: Bacon auto-inherits singleton methods to child contexts
      # by using the runtime and won't include methods in modules included
      # by the parent context. We have to ensure that the methods will be
      # accessible by the child contexts by defining them as singleton methods.
      TemporaryRepos.instance_methods.each do |method|
        unbound_method = base.method(method).unbind
        base.define_singleton_method method do |*args, &b|
          unbound_method.bind(self).call(*args, &b)
        end
      end

      base.before do
        tmp_repos_path.mkpath
      end
    end
  end
end
