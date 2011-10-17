require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::BridgeSupportGenerator" do
  it "generates a metadata file with the appropriate search paths" do
    headers = %w{ /some/dir/foo.h /some/dir/bar.h /some/other/dir/baz.h }.map { |h| Pathname.new(h) }
    generator = Pod::BridgeSupportGenerator.new(headers)
    def generator.gen_bridge_metadata(command)
      @command = command
    end
    generator.create_in(Pathname.new("/path/to/Pods"))
    generator.instance_variable_get(:@command).should ==
      %{-c "-I '/some/dir' -I '/some/other/dir'" -o '/path/to/Pods/Pods.bridgesupport' '#{headers.join("' '")}'}
  end
end
