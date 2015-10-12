module Pod
  class Specification
    class Set
      class LazySpecification < BasicObject
        attr_reader :name, :version, :source

        def initialize(name, version, source)
          @name = name
          @version = version
          @source = source
        end

        def method_missing(method, *args, &block)
          specification.send(method, *args, &block)
        end

        def respond_to_missing?(method, include_all = false)
          specification.respond_to?(method, include_all)
        end

        def subspec_by_name(name = nil, raise_if_missing = true)
          if !name || name == self.name
            self
          else
            specification.subspec_by_name(name, raise_if_missing)
          end
        end

        def specification
          @specification ||= source.specification(name, version.version)
        end
      end

      class External
        def all_specifications
          [specification]
        end
      end

      def all_specifications
        @all_specifications ||= begin
          sources_by_version = {}
          versions_by_source.each do |source, versions|
            versions.each { |v| (sources_by_version[v] ||= []) << source }
            sources_by_version
          end

          duplicate_versions = sources_by_version.select { |_version, sources| sources.count > 1 }

          duplicate_versions.each do |version, sources|
            UI.warn "Found multiple specifications for `#{name} (#{version})`:\n" +
              sources.
                map { |s| s.specification_path(name, version) }.
                map { |v| "- #{v}" }.join("\n")
          end

          versions_by_source.flat_map do |source, versions|
            versions.map { |version| LazySpecification.new(name, version, source) }
          end
        end
      end
    end
  end
end
