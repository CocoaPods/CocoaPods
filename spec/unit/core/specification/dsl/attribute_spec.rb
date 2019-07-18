require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  describe Attribute = Specification::DSL::Attribute do
    describe 'In general' do
      it 'returns the name' do
        attr = Attribute.new('name', {})
        attr.name.should == 'name'
      end

      it 'raises for not recognized options' do
        opts = { :unrecognized => true }
        lambda { Attribute.new('name', opts) }.should.raise StandardError
      end

      it 'returns a string representation suitable for UI' do
        s = 'Specification attribute `name`'
        Attribute.new('name', {}).to_s.should == s
      end

      it 'returns the accepted classes for the value of the attribute' do
        opts = { :types => [String], :container => Array }
        Attribute.new('name', opts).supported_types.should == [String, Array]
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Options' do
      before do
        @attr = Attribute.new('name', {})
      end

      it 'is multi platform by default' do
        @attr.should.be.multi_platform
      end

      it 'is not inherited by default' do
        @attr.should.not.be.inherited
      end

      it 'is not root only by default' do
        @attr.should.not.be.root_only
      end

      it 'is not required by default' do
        @attr.should.not.be.required
      end

      it "doesn't want a singular form by default" do
        @attr.should.not.be.required
      end

      it 'is not a file pattern by default' do
        @attr.should.not.be.file_patterns
      end

      it "doesn't specifies a container by default" do
        @attr.container.should.be.nil
      end

      it "doesn't specifies accepted keys for a hash container by default" do
        @attr.keys.should.be.nil
      end

      it "doesn't specifies a default value by default (multi platform)" do
        @attr.default_value.should.be.nil
      end

      it "doesn't specifies a default value by default (no multi platform)" do
        @attr = Attribute.new('name', :multi_platform => false)
        @attr.default_value.should.be.nil
      end

      it 'specifies `String` as the default type' do
        @attr.types.should == [String]
      end

      it 'is inherited by default if it is root only' do
        attr = Attribute.new('name', :root_only => true)
        attr.should.be.inherited
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Accessors support' do
      it 'returns the default value' do
        attr1 = Attribute.new(:frameworks, :multi_platform => false)
        attr1.default.should.be.nil?
        attr2 = Attribute.new(:frameworks, :multi_platform => false, :default_value => ['Cocoa'])
        attr2.default.should == ['Cocoa']
      end

      it 'returns the default value for a platform' do
        attr = Attribute.new(:frameworks, :default_value => ['CoreGraphics'])
        attr.default(:ios).should == ['CoreGraphics']
      end

      it 'allows to specify the default value per platform' do
        attr = Attribute.new(:frameworks, :ios_default => ['CoreGraphics'])
        attr.default(:ios).should == ['CoreGraphics']
        attr.default(:osx).should.be.nil
      end

      it 'returns the name of the writer method' do
        attr = Attribute.new(:frameworks, :singularize => true)
        attr.writer_name.should == 'frameworks='
      end

      it 'returns the singular form of the writer method' do
        attr = Attribute.new(:frameworks,  :singularize => true)
        attr.writer_singular_form.should == 'framework='
      end
    end
  end
end
