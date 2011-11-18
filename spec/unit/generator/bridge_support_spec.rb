require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Generator::BridgeSupport" do
  it "generates a metadata file with the appropriate search paths" do
    headers = %w{ /some/dir/foo.h /some/dir/bar.h /some/other/dir/baz.h }.map { |h| Pathname.new(h) }
    generator = Pod::Generator::BridgeSupport.new(headers)
    def generator.gen_bridge_metadata(command)
      @command = command
    end
    generator.save_as(Pathname.new("/path/to/Pods.bridgesupport"))
    generator.instance_variable_get(:@command).should ==
      %{-c "-I '/some/dir' -I '/some/other/dir'" -o '/path/to/Pods.bridgesupport' '#{headers.join("' '")}'}
  end
end
