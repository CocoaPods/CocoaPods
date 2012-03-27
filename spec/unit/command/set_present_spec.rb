require File.expand_path('../../../spec_helper', __FILE__)
require 'net/http'

describe Pod::Command::SetPresent do

  before do
    @set = Pod::Spec::Set.new(fixture('spec-repos/master/CocoaLumberjack'))
    @dummy = Object.new
    @dummy.extend(Pod::Command::SetPresent)
    def @dummy.puts(msg = '') (@printed ||= '') << "#{msg}\n" end
    def @dummy.prinded() @printed.chomp end
  end

  it "repects the `--name-only' option" do
    @dummy.parse_set_options(argv('--name-only'))
    @dummy.present_set(@set)
    @dummy.prinded.should == 'CocoaLumberjack'
  end

  it "presents the name, version, description, homepage and source of a specification set" do
    @dummy.parse_set_options(argv())
    @dummy.present_set(@set)
    @dummy.prinded.should.include? 'CocoaLumberjack'
    @dummy.prinded.should.include? '1.0'
    @dummy.prinded.should.include? '1.1'
    @dummy.prinded.should.include? 'A fast & simple, yet powerful & flexible logging framework for Mac and iOS.'
    @dummy.prinded.should.include? 'https://github.com/robbiehanson/CocoaLumberjack'
    @dummy.prinded.should.include? 'https://github.com/robbiehanson/CocoaLumberjack.git'
  end

  it "presents the stats of a specification set" do
    response = '{"repository":{"homepage":"","url":"https://github.com/robbiehanson/CocoaLumberjack","has_downloads":true,"has_issues":true,"language":"Objective-C","master_branch":"master","forks":42,"fork":false,"created_at":"2011/03/30 19:38:39 -0700","has_wiki":true,"description":"A fast & simple, yet powerful & flexible logging framework for Mac and iOS","size":416,"private":false,"name":"CocoaLumberjack","owner":"robbiehanson","open_issues":4,"watchers":318,"pushed_at":"2012/03/26 12:39:36 -0700"}}% '
    Net::HTTP.expects(:get).with('github.com', '/api/v2/json/repos/show/robbiehanson/CocoaLumberjack').returns(response)
    @dummy.parse_set_options(argv('--stats'))
    @dummy.present_set(@set)
    @dummy.prinded.should.match(/Watchers:\W+[0-9]+/)
    @dummy.prinded.should.match(/Forks:\W+[0-9]+/)
  end

end

