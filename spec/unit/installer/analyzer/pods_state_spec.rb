require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Installer::Analyzer::PodsState do

    describe "In general" do

      it "raises if there is an attempt to add the name of a subspec" do
        should.raise do
          sut = Installer::Analyzer::PodsState.new
          sut.add_name('Pod/Subspec', :added)
        end
      end

    end

    #-------------------------------------------------------------------------#

  end
end
