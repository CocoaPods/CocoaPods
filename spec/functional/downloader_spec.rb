require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Downloader" do
  before do
    @dir = temporary_directory + 'banana-lib'
  end

  describe "for Git" do
    extend SpecHelper::TemporaryDirectory

    it "check's out a specific commit" do
      downloader = Pod::Downloader.for_source(@dir,
        :git => fixture('banana-lib'), :commit => '02467b074d4dc9f6a75b8cd3ab80d9bf37887b01'
      )
      downloader.download
      (@dir + 'README').read.strip.should == 'first commit'
    end

    it "check's out a specific tag" do
      downloader = Pod::Downloader.for_source(@dir,
        :git => fixture('banana-lib'), :tag => 'v1.0'
      )
      downloader.download
      (@dir + 'README').read.strip.should == 'v1.0'
    end

    it "removes the .git directory" do
      downloader = Pod::Downloader.for_source(@dir,
        :git => fixture('banana-lib'), :tag => 'v1.0'
      )
      downloader.download
      downloader.clean
      (@dir + '.git').should.not.exist
    end

    it "removes the clean_paths files and directories" do
      downloader = Pod::Downloader.for_source(@dir,
        :git => fixture('banana-lib'), :tag => 'v1.0'
      )
      downloader.download
      downloader.clean([@dir + 'README'])
      (@dir + 'README').should.not.exist
    end
  end

  describe "for Mercurial" do
    extend SpecHelper::TemporaryDirectory

    it "check's out a specific revision" do
      downloader = Pod::Downloader.for_source(@dir,
        :hg => fixture('mercurial-repo'), :revision => '46198bb3af96'
      )
      downloader.download
      (@dir + 'README').read.strip.should == 'first commit'
    end

    it "removes the .hg directory" do
      downloader = Pod::Downloader.for_source(@dir,
        :hg => fixture('mercurial-repo'), :revision => '46198bb3af96'
      )
      downloader.download
      downloader.clean
      (@dir + '.hg').should.not.exist
    end

    it "removes the clean_paths files and directories" do
      downloader = Pod::Downloader.for_source(@dir,
        :hg => fixture('mercurial-repo'), :revision => '46198bb3af96'
      )
      downloader.download
      downloader.clean([@dir + 'README'])
      (@dir + 'README').should.not.exist
    end

  end

end

