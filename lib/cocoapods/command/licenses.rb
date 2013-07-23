module Pod
  class Command
    class Licenses < Command
      self.summary = 'Show licenses of installed pods'

      self.description = <<-DESC
        Shows the licenses of installed pods
      DESC

      def initialize(argv)
        super
      end

      def run
        verify_podfile_exists!
        verify_lockfile_exists!

        lockfile = config.lockfile
        pods = lockfile.pod_names
        licenses = []
        deps = lockfile.dependencies.map{|d| d.name}
        pods = (deps + pods).uniq
        pods.each do |pod_name|
          spec = (Pod::SourcesManager.search_by_name(pod_name).first rescue nil)
          license = "Unknown"
          if spec
            specification = spec.specification
            license = specification.license[:type] || "Unknown"
          end
          licenses << [pod_name, license]
        end

        if licenses.empty?
          UI.puts "No pods found.".yellow
        else
          UI.section "Licenses:" do
            licenses.each do |(name, license)|
              UI.puts "#{name}: #{license}"
            end
          end
        end
      end
    end
  end
end


