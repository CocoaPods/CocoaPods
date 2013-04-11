require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::PodfileInfo do
    extend SpecHelper::TemporaryRepos

    before do
      @test_source = Source.new(fixture('spec-repos/test_repo'))
      Source::Aggregate.any_instance.stubs(:all).returns([@test_source])
      SourcesManager.updated_search_index = nil
    end

    it "tells the user pods info from Podfile" do

      file = temporary_directory + 'Podfile'

      text = <<-PODFILE
      platform :ios
      pod 'BananaLib'
      pod 'JSONKit'
      PODFILE
      File.open(file, 'w') {|f| f.write(text) }

      Dir.chdir(temporary_directory) do
        output = run_command('podfile-info')
        output.should.include? '- BananaLib - Chunky bananas!'
        output.should.include? '- JSONKit - A Very High Performance Objective-C JSON Library.'
      end
    end
  end
end

