module Pod
  class Command
    class List < Command
      def self.banner
%{List all pods:

    $ pod list

      Lists all available pods.}
      end

      def initialize(argv)
      end

      def run
        Source.all.each do |source|
          source.pod_sets.each do |set|
            puts "==> #{set.name} (#{set.versions.reverse.join(", ")})"
            puts "    #{set.specification.summary.strip}"
            puts
          end
        end
      end
    end
  end
end
