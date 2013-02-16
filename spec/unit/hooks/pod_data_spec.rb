require File.expand_path('../../../spec_helper', __FILE__)

# Stubs an object ensuring that it responds to the given method
#
def safe_stub(object, method, return_value)
  object.should.respond_to?(method)
  object.stubs(method).returns(return_value)
end

module Pod
  describe Hooks::PodData do

    before do

    end

    #-------------------------------------------------------------------------#

    describe "Public Hooks API" do


    end

    #-------------------------------------------------------------------------#

    describe "Unsafe Hooks API" do

      it "provides the config to the specification" do
        spec = Spec.new(nil, 'Name')
        spec.config.should == config
      end

    end

    #-------------------------------------------------------------------------#

  end
end
