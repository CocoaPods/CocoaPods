require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Specification::DSL::AttributeSupport do
    class TestClass
      extend Pod::Specification::DSL::AttributeSupport
      root_attribute :test_root_attribute,  :types => [String]
      attribute :test_attribute,  :types => [String], :root_only => false

      class << self
        attr_reader :attributes
      end
    end

    #-------------------------------------------------------------------------#

    it 'stores the attributes' do
      TestClass.attributes.keys.sort_by(&:to_s).should == [
        :test_attribute, :test_root_attribute
      ]
    end

    it 'declares a root attribute' do
      attr = TestClass.attributes[:test_root_attribute]
      attr.class.should == Specification::DSL::Attribute
    end

    it 'declares root attributes with the `root_only` option' do
      attr = TestClass.attributes[:test_root_attribute]
      attr.should.be.root_only?
    end

    it 'declares root attributes without the `multi_platform` option' do
      attr = TestClass.attributes[:test_root_attribute]
      attr.should.not.be.multi_platform?
    end

    it 'declares a normal attribute' do
      attr = TestClass.attributes[:test_attribute]
      attr.class.should == Specification::DSL::Attribute
    end

    it 'declares normal attributes without the `root_only` option' do
      attr = TestClass.attributes[:test_attribute]
      attr.should.not.be.root_only?
    end

    it 'declares root attributes with the `multi_platform` option by default' do
      attr = TestClass.attributes[:test_attribute]
      attr.should.be.multi_platform?
    end

    #-------------------------------------------------------------------------#
  end
end
