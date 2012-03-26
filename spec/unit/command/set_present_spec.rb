require File.expand_path('../../../spec_helper', __FILE__)

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

    puts
    puts "\n\n\n\n============================================================="
    puts "TEST FOR CURL"
    puts `curl -m 2 http://github.com/api/v2/json/repos/show/cocoapods/cocoapods`
    puts "=============================================================\n\n\n\n"

    @dummy.parse_set_options(argv('--stats'))
    @dummy.present_set(@set)
    @dummy.prinded.should.match(/Watchers:\W+[0-9]+/)
    @dummy.prinded.should.match(/Forks:\W+[0-9]+/)
  end

end

