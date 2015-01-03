require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Repo do
    it 'defaults to the list subcommand' do
      Command::Repo.default_subcommand.should == 'list'
    end
  end
end
