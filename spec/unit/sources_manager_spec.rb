require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe SourcesManager do

    describe "In general" do
      it "returns all the sources" do
        SourcesManager.all.map(&:name).should == %w[master test_repo]
      end

      it "returns all the sets" do
        SourcesManager.all_sets.map(&:name).should.include?('Chameleon')
      end

      it "searches for the set of a dependency" do
        set = SourcesManager.search(Dependency.new('Chameleon'))
        set.class.should == Specification::Set
        set.name.should == 'Chameleon'
      end

      it "searches sets by name" do
        sets = SourcesManager.search_by_name('Chameleon')
        sets.all?{ |s| s.class == Specification::Set}.should.be.true
        sets.any?{ |s| s.name  == 'Chameleon'}.should.be.true
      end

      it "can perform a full text search of the sets" do
        sets = SourcesManager.search_by_name('Drop in sharing', true)
        sets.all?{ |s| s.class == Specification::Set}.should.be.true
        sets.any?{ |s| s.name  == 'ShareKit'}.should.be.true
      end
    end

    #-------------------------------------------------------------------------#

    describe "Updating Sources" do
      extend SpecHelper::TemporaryDirectory
      extend SpecHelper::TemporaryRepos

      it "update source backed by a git repository" do
        set_up_test_repo
        upstream = SpecHelper.temporary_directory + 'upstream'
        FileUtils.cp_r(test_repo_path, upstream)
        Dir.chdir(test_repo_path) do
          `git remote add origin #{upstream}`
          `git remote -v`
          `git fetch -q`
          `git branch --set-upstream master origin/master`
        end
        config.repos_dir = SpecHelper.tmp_repos_path

        SourcesManager.update(test_repo_path.basename.to_s, true)
        UI.output.should.match /Already up-to-date/
      end

      it "returns whether a source is backed by a git repo" do
        SourcesManager.git_repo?(SourcesManager.master_repo_dir).should.be.true
        SourcesManager.git_repo?(Pathname.new('/tmp')).should.be.false
      end

      it "informs the user if there is an update for CocoaPods" do
        SourcesManager.stubs(:version_information).returns({ 'last' => '999.0' })
        SourcesManager.check_version_information(temporary_directory)
        UI.output.should.match /Cocoapods 999.0 is available/
      end

      it "raises while asked to version information of a source if it is not compatible" do
        SourcesManager.stubs(:version_information).returns({ 'min' => '999.0' })
        e = lambda { SourcesManager.check_version_information(temporary_directory) }.should.raise Informative
        e.message.should.match /Update Cocoapods/
        SourcesManager.stubs(:version_information).returns({ 'max' => '0.0.1' })
        e = lambda { SourcesManager.check_version_information(temporary_directory) }.should.raise Informative
        e.message.should.match /Update Cocoapods/
      end

      it "returns whether a repository is compatible" do
        SourcesManager.stubs(:version_information).returns({ 'min' => '0.0.1' })
        SourcesManager.repo_compatible?('stub').should.be.true

        SourcesManager.stubs(:version_information).returns({ 'max' => '999.0' })
        SourcesManager.repo_compatible?('stub').should.be.true

        SourcesManager.stubs(:version_information).returns({ 'min' => '999.0' })
        SourcesManager.repo_compatible?('stub').should.be.false

        SourcesManager.stubs(:version_information).returns({ 'max' => '0.0.1' })
        SourcesManager.repo_compatible?('stub').should.be.false
      end

      it "returns whether there is a CocoaPods update available" do
        SourcesManager.cocoapods_update?({ 'last' => '0.0.1' }).should.be.false
        SourcesManager.cocoapods_update?({ 'last' => '999.0' }).should.be.true
      end

      it "it returns an empty array for the version information if the file can't be found" do
        SourcesManager.version_information(temporary_directory).should == {}
      end

    end

    #-------------------------------------------------------------------------#

    describe "Master repo" do
      extend SpecHelper::TemporaryDirectory

      it "returns the master repo dir" do
        SourcesManager.master_repo_dir.to_s.should.match /fixtures\/spec-repos\/master/
      end

      it "returns whether the master repo is functional" do
        SourcesManager.master_repo_functional?.should.be.true
        config.repos_dir = SpecHelper.temporary_directory
        SourcesManager.master_repo_functional?.should.be.false
      end

    end
  end
end
