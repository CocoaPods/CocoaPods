module Pod
  module Xcode
    class CopyResourcesScript
      attr_reader :resources

      # A list of files relative to the project pods root.
      def initialize(resources)
        @resources = resources
      end

      def create_in(root)
        return if @resources.empty?
        (root + 'PodsResources.sh').open('a') do |script|
          @resources.each do |resource|
            script.puts "install_resource '#{resource}'"
          end
        end
      end
    end
  end
end
