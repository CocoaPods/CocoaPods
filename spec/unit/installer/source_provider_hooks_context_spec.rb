
require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::SourceProviderHooksContext do
    it 'offers a convenience method to be generated' do
      result = Installer::SourceProviderHooksContext.generate
      result.class.should == Installer::SourceProviderHooksContext
      result.sources.should == []
    end
  end
end
