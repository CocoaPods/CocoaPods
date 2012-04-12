require File.expand_path('../../../spec_helper', __FILE__)
require 'net/http'

describe Pod::Command::Presenter do

  Presenter = Pod::Command::Presenter

  before do
    @set = Pod::Spec::Set.new(fixture('spec-repos/master/CocoaLumberjack'))
    Pod::Specification::Statistics.instance.cache_file = nil
  end

  it "presents the name, version, description, homepage and source of a specification set" do
    presenter = Presenter.new(argv())
    output    = presenter.render_set(@set)
    output.should.include? 'CocoaLumberjack'
    output.should.include? '1.0'
    output.should.include? '1.1'
    output.should.include? 'A fast & simple, yet powerful & flexible logging framework for Mac and iOS.'
    output.should.include? 'https://github.com/robbiehanson/CocoaLumberjack'
    output.should.include? 'https://github.com/robbiehanson/CocoaLumberjack.git'
  end

  it "presents the stats of a specification set" do
    response = '{"repository":{"homepage":"","url":"https://github.com/robbiehanson/CocoaLumberjack","has_downloads":true,"has_issues":true,"language":"Objective-C","master_branch":"master","forks":42,"fork":false,"created_at":"2011/03/30 19:38:39 -0700","has_wiki":true,"description":"A fast & simple, yet powerful & flexible logging framework for Mac and iOS","size":416,"private":false,"name":"CocoaLumberjack","owner":"robbiehanson","open_issues":4,"watchers":318,"pushed_at":"2012/03/26 12:39:36 -0700"}}% '
    Pod::Specification::Statistics.instance.expects(:fetch_stats).with("robbiehanson", "CocoaLumberjack").returns(response)
    presenter = Presenter.new(argv('--stats'))
    output = presenter.render_set(@set)
    output.should.include? 'Author:   Robbie Hanson'
    output.should.include? 'License:  BSD'
    output.should.include? 'Platform: iOS - OS X'
    output.should.include? 'Watchers: 318'
    output.should.include? 'Forks:    42'
  end

end

