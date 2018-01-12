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

        def subspec_by_name(name = nil, raise_if_missing = true, include_test_specifications = false)
          if !name || name == self.name
            self
          else
            specification.subspec_by_name(name, raise_if_missing, include_test_specifications)
          end
        end

        def specification
          @specification ||= source.specification(name, version.version)
        end
      end

      class External
        def all_specifications(_warn_for_multiple_pod_sources)
          [specification]
        end
      end

      # returns the highest versioned spec last
      def all_specifications(warn_for_multiple_pod_sources)
        @all_specifications ||= begin
          sources_by_version = {}
          versions_by_source.each do |source, versions|
            versions.each { |v| (sources_by_version[v] ||= []) << source }
          end

          if warn_for_multiple_pod_sources
            duplicate_versions = sources_by_version.select { |_version, sources| sources.count > 1 }

            duplicate_versions.each do |version, sources|
              UI.warn "Found multiple specifications for `#{name} (#{version})`:\n" +
                sources.
                  map { |s| s.specification_path(name, version) }.
                  map { |v| "- #{v}" }.join("\n")
            end
          end

          # sort versions from high to low
          sources_by_version.sort_by(&:first).flat_map do |version, sources|
            # within each version, we want the prefered (first-specified) source
            # to be the _last_ one
            sources.reverse_each.map { |source| LazySpecification.new(name, version, source) }
          end
        end
      end
    end
  end
end
