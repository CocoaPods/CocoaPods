require File.expand_path('../../spec_helper', __FILE__)
require 'net/http'

module Pod
  describe UI do
    extend SpecHelper::Command

    before do
      @set = config.sources_manager.search(Dependency.new('CocoaLumberjack'))
    end

    it 'presents the name, version, description, homepage and source of a specification set' do
      UI.pod(@set)
      output = UI.output
      output.should.include? 'CocoaLumberjack'
      output.should.include? '1.0'
      output.should.include? '1.1'
      output.should.include? '[trunk repo]'
      output.should.include? 'A fast & simple, yet powerful & flexible logging framework for Mac and iOS.'
      output.should.include? 'https://github.com/CocoaLumberjack/CocoaLumberjack'
      output.should.include? 'https://github.com/CocoaLumberjack/CocoaLumberjack.git'
    end

    it 'Presents information about deprecation if the pod is deprecated' do
      specification = @set.specification
      specification.deprecated = true
      @set.expects(:specification).returns(specification)
      UI.pod(@set)
      output = UI.output
      output.should.include? '[DEPRECATED]'
    end

    it 'Presents information about the deprecation in favor of another pod' do
      specification = @set.specification
      specification.deprecated_in_favor_of = 'NewMoreAwesomePod'
      @set.expects(:specification).returns(specification)

      UI.pod(@set)
      output = UI.output
      output.should.include? '[DEPRECATED in favor of NewMoreAwesomePod]'
    end

    it 'presents the stats of a specification set' do
      Specification::Set::Presenter.any_instance.expects(:platform).returns('iOS 5.0 - macOS 10.7')
      Specification::Set::Presenter.any_instance.expects(:github_stargazers).returns('318')
      Specification::Set::Presenter.any_instance.expects(:github_forks).returns('42')
      UI.pod(@set, :stats)
      output = UI.output
      output.should.include? 'Author:   Robbie Hanson'
      output.should.include? 'License:  BSD'
      output.should.include? 'Platform: iOS 5.0 - macOS 10.7'
      output.should.include? 'Stars:    318'
      output.should.include? 'Forks:    42'
    end

    it 'should print at least one subspec' do
      @set = config.sources_manager.search(Dependency.new('RestKit'))
      UI.pod(@set)
      output = UI.output
      output.should.include? 'RestKit/Network'
    end

    it 'presents only name and version of a specification set in :name_and_version mode' do
      @set = config.sources_manager.search_by_name('RestKit').first
      UI.pod(@set, :name_and_version)
      output = UI.output
      output.should.include? "RestKit #{@set.versions.first}"
    end
  end
end
