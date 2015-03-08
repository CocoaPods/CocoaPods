module Pod
  class Sandbox
    class PodspecFinder
      attr_reader :root

      def initialize(root)
        @root = root
      end

      def podspecs
        return @specs_by_name if @specs_by_name
        @specs_by_name = {}
        spec_files = Dir.glob(root + '{,*,*/*}.podspec{,.json}')
        spec_files.sort_by { |p| -p.split(File::SEPARATOR).size }.each do |file|
          begin
            spec = Specification.from_file(file)
            @specs_by_name[spec.name] = spec
          rescue => e
            UI.warn "Unable to load a podspec from #{file}, skipping:\n\n#{e}"
          end
        end
        @specs_by_name
      end
    end
  end
end
