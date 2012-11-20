require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Pod::Source do

    it "returns all the sources" do
      Source.all.map(&:name).should == %w[master test_repo]
    end

    it "returns all the sets" do
      Source.all_sets.map(&:name).should.include?('Chameleon')
    end

    it "searches for the set of a dependency" do
      set = Source.search(Dependency.new('Chameleon'))
      set.class.should == Pod::Specification::Set
      set.name.should == 'Chameleon'
    end

    it "searches sets by name" do
      sets = Source.search_by_name('Chameleon')
      sets.all?{ |s| s.class == Pod::Specification::Set}.should.be.true
      sets.any?{ |s| s.name  == 'Chameleon'}.should.be.true
    end

    it "can perform a full text search of the sets" do
      sets = Source.search_by_name('Drop in sharing', true)
      sets.all?{ |s| s.class == Pod::Specification::Set}.should.be.true
      sets.any?{ |s| s.name  == 'ShareKit'}.should.be.true
    end
  end
end
