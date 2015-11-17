require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command do
    it 'returns the proper command class' do
      Command.parse(%w(install      )).should.be.instance_of Command::Install
      Command.parse(%w(list         )).should.be.instance_of Command::List
      Command.parse(%w(outdated     )).should.be.instance_of Command::Outdated
      Command.parse(%w(repo         )).should.be.instance_of Command::Repo::List
      Command.parse(%w(repo add     )).should.be.instance_of Command::Repo::Add
      Command.parse(%w(repo lint    )).should.be.instance_of Command::Repo::Lint
      Command.parse(%w(repo list    )).should.be.instance_of Command::Repo::List
      Command.parse(%w(repo update  )).should.be.instance_of Command::Repo::Update
      Command.parse(%w(repo remove  )).should.be.instance_of Command::Repo::Remove
      Command.parse(%w(setup        )).should.be.instance_of Command::Setup
      Command.parse(%w(spec create  )).should.be.instance_of Command::Spec::Create
      Command.parse(%w(spec lint    )).should.be.instance_of Command::Spec::Lint
      Command.parse(%w(init         )).should.be.instance_of Command::Init
      Command.parse(%w(env          )).should.be.instance_of Command::Env
    end
  end
end
