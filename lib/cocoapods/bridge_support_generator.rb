module Pod
  class BridgeSupportGenerator
    include Config::Mixin

    extend Executable
    executable :gen_bridge_metadata

    attr_reader :headers

    def initialize(headers)
      @headers = headers
    end

    def search_paths
      @headers.map { |header| "-I '#{header.dirname}'" }.uniq
    end

    def create_in(root)
      puts "==> Generating BridgeSupport metadata file" unless config.silent?
      cflags = %{-c "#{search_paths.join(' ')}"}
      output = %{-o '#{root + "Pods.bridgesupport"}'}
      gen_bridge_metadata %{#{cflags} #{output} '#{headers.join("' '")}'}
    end
  end
end
