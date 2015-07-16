require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe 'Pod::Generator::BridgeSupport' do
    if Executable.which('gen_bridge_metadata').nil?
      puts '  ! '.red << "Skipping because the `gen_bridge_metadata` executable can't be found."
    else
      it 'generates a metadata file with the appropriate search paths' do
        headers = %w(/some/dir/foo.h /some/dir/bar.h /some/other/dir/baz.h).map { |h| Pathname.new(h) }
        generator = Generator::BridgeSupport.new(headers)
        expected = ['-c', "-I '/some/dir' -I '/some/other/dir'", '-o', '/path/to/Pods.bridgesupport', *headers]
        generator.expects(:gen_bridge_metadata).with { |*command| command.map(&:to_s) == expected.map(&:to_s) }
        generator.save_as(Pathname.new('/path/to/Pods.bridgesupport'))
      end
    end
  end
end
