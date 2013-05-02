require File.expand_path('../../spec_helper', __FILE__)
require 'net/http'

module Pod
  describe UI do
    extend SpecHelper::Command

    before do
      @set = SourcesManager.search(Dependency.new('CocoaLumberjack'))
    end

    it "presents the name, version, description, homepage and source of a specification set" do
      UI.pod(@set)
      output = UI.output
      output.should.include? 'CocoaLumberjack'
      output.should.include? '1.0'
      output.should.include? '1.1'
      output.should.include? '[master repo]'
      output.should.include? 'A fast & simple, yet powerful & flexible logging framework for Mac and iOS.'
      output.should.include? 'https://github.com/robbiehanson/CocoaLumberjack'
      output.should.include? 'https://github.com/robbiehanson/CocoaLumberjack.git'
    end

    it "presents the stats of a specification set" do
      repo = { "forks"=>42, "watchers"=>318, "pushed_at"=>"2011-01-26T19:06:43Z" }
      Octokit.expects(:repo).with("robbiehanson/CocoaLumberjack").returns(repo)
      UI.pod(@set, :stats)
      output = UI.output
      output.should.include? 'Author:   Robbie Hanson'
      output.should.include? 'License:  BSD'
      output.should.include? 'Platform: iOS - OS X'
      output.should.include? 'Watchers: 318'
      output.should.include? 'Forks:    42'
      output.should.include? 'Pushed:   more than a year ago'
    end

    it "should print at least one subspec" do
      @set = SourcesManager.search_by_name('RestKit').first
      UI.pod(@set)
      output = UI.output
      output.should.include? "RestKit/Network"
    end
  end
end

