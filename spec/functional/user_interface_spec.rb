require File.expand_path('../../spec_helper', __FILE__)
require 'net/http'

describe Pod::UI do
  extend SpecHelper::Command

  before do
    @set = Pod::Source.search_by_name('CocoaLumberjack').first
    Pod::Specification::Statistics.instance.cache_file = nil
  end

  it "presents the name, version, description, homepage and source of a specification set" do
    Pod::UI.pod(@set)
    output = Pod::UI.output.gsub(/\n */,'')
    output.should.include? 'CocoaLumberjack'
    output.should.include? '1.0'
    output.should.include? '1.1'
    output.should.include? 'A fast & simple, yet powerful & flexible logging framework for Mac and iOS.'
    output.should.include? 'https://github.com/robbiehanson/CocoaLumberjack'
    output.should.include? 'https://github.com/robbiehanson/CocoaLumberjack.git'
  end


  it "presents the name, version, description, homepage and source of a specification set" do
    Pod::UI.pod(@set)
    output = Pod::UI.output.gsub(/\n */,'')
    output.should.include? 'Versions: 1.6, 1.3.3, 1.3.2, 1.3.1, 1.3, 1.2.3, 1.2.2, 1.2.1, 1.2, 1.1, 1.0 [master repo]'
  end

  it "presents the stats of a specification set" do
    repo = { "forks"=>42, "watchers"=>318, "pushed_at"=>"2011-01-26T19:06:43Z" }
    Octokit.expects(:repo).with("robbiehanson/CocoaLumberjack").returns(repo)
    Pod::UI.pod(@set, :stats)
    output = Pod::UI.output
    output.should.include? 'Author:   Robbie Hanson'
    output.should.include? 'License:  BSD'
    output.should.include? 'Platform: iOS - OS X'
    output.should.include? 'Watchers: 318'
    output.should.include? 'Forks:    42'
    output.should.include? 'Pushed:   more than a year ago'
  end

  it "should print at least one subspec" do
    @set = Pod::Source.search_by_name('RestKit').first
    Pod::UI.pod(@set)
    output = Pod::UI.output
    output.should.include? "RestKit/Network"
  end
end

