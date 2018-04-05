require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe ExternalSources do
    before do
      @subject = ExternalSources
    end

    describe 'from_dependency' do
      it 'supports a podspec source' do
        dep = Dependency.new('Reachability', :podspec => '')
        klass = @subject.from_dependency(dep, nil, true).class
        klass.should == @subject::PodspecSource
      end

      it 'supports a path source' do
        dep = Dependency.new('Reachability', :path => '')
        klass = @subject.from_dependency(dep, nil, true).class
        klass.should == @subject::PathSource
      end

      it 'supports all the strategies implemented by the downloader' do
        [:git, :svn, :hg, :bzr, :http].each do |strategy|
          dep     = Dependency.new('Reachability', strategy => '')
          klass = @subject.from_dependency(dep, nil, true).class
          klass.should == @subject::DownloaderSource
        end
      end
    end
  end
end
