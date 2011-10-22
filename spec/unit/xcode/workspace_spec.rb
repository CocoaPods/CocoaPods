require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Xcode::Workspace" do
  before do
    @workspace = Pod::Xcode::Workspace.new('Pods/Pods.xcodeproj', 'App.xcodeproj')
    @doc = NSXMLDocument.alloc.initWithXMLString(@workspace.to_s, options:0, error:nil)
  end
  
  it "is the right workspace version" do
    @doc.rootElement.attributeForName("version").stringValue.should == "1.0"
  end
  
  it "contains the projects" do
    @doc.nodesForXPath("/Workspace/FileRef", error:nil).map do |node|
      node.attributeForName("location").stringValue.sub(/^group:/, '')
    end.sort.should == ['App.xcodeproj', 'Pods/Pods.xcodeproj']
  end
end
