require 'active_support/core_ext/string/strip'

module Pod
  class Command
    class Open < Command

      self.summary = 'Open the workspace'
      self.description = <<-DESC
        Opens the workspace in xcode. If no workspace found in the current directory,
        looks up until it finds one.
      DESC

      def initialize(argv)
        @workspace = find_workspace_in(Pathname.pwd)
        super
      end

      def validate!
        super
        raise Informative, "No xcode workspace found" unless @workspace
      end

      def run
        `open #{@workspace}`
      end

      private

      def find_workspace_in(path)
        path.children.find {|fn| fn.extname == '.xcworkspace'} || find_workspace_in_parent(path)
      end

      def find_workspace_in_parent(path)
        find_workspace_in(path.parent) unless path.root?
      end
    end
  end
end
