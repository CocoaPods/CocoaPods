module Pod
  class Installer
    class Analyzer
      # Collects all {PodVariant}.
      class PodVariantSet
        # @return [Array<PodVariant>] the different variants.
        #
        attr_accessor :variants

        # Initialize a new instance.
        #
        # @param [Array<PodVariant>] variants  @see #variants
        #
        def initialize(variants)
          self.variants = variants
        end

        # Describes what makes each {PodVariant} distinct among the others.
        #
        # @return [Hash<PodVariant, String>]
        #
        def scope_suffixes
          return { variants.first => nil } if variants.count == 1
          scope_by_specs
        end

        # Groups the collection by result of the block.
        #
        # @param [Block<Variant, #hash>] block
        # @return [Array<PodVariantSet>]
        #
        def group_by(&block)
          variants.group_by(&block).map { |_, v| PodVariantSet.new(v) }
        end

        # @private
        #
        # Prepends the given scoped {PodVariant}s with another scoping label, if there
        # was more than one group of {PodVariant}s given.
        #
        # @param [Array<Hash<PodVariant, String>>] scoped_variants
        #        {PodVariant}s, which where grouped on base of a criteria, which is used
        #        in the block argument to generate a descriptive label.
        #
        # @param [Block<PodVariant, String>] block
        #        takes a {PodVariant} and returns a scope suffix which is prepended, if
        #        necessary.
        #
        # @return [Hash<PodVariant, String>]
        #
        def scope_if_necessary(scoped_variants, &block)
          if scoped_variants.count == 1
            return scoped_variants.first
          end
          Hash[scoped_variants.flat_map do |variants|
            variants.map do |variant, suffix|
              prefix = block.call(variant)
              scope = [prefix, suffix].compact.join('-')
              [variant, !scope.empty? ? scope : nil]
            end
          end]
        end

        # @private
        # @return [Hash<PodVariant, String>]
        #
        def scope_by_build_type
          scope_if_necessary(group_by(&:requires_frameworks).map(&:scope_by_platform)) do |variant|
            variant.requires_frameworks? ? 'framework' : 'library'
          end
        end

        # @private
        # @return [Hash<PodVariant, String>]
        #
        def scope_by_platform
          grouped_variants = group_by { |v| v.platform.name }
          if grouped_variants.all? { |set| set.variants.count == 1 }
            # => Platform name
            platform_name_proc = proc { |v| Platform.string_name(v.platform.symbolic_name).tr(' ', '') }
          else
            grouped_variants = group_by(&:platform)
            # => Platform name + SDK version
            platform_name_proc = proc { |v| v.platform.to_s.tr(' ', '') }
          end
          scope_if_necessary(grouped_variants.map(&:scope_without_suffix), &platform_name_proc)
        end

        # @private
        # @return [Hash<PodVariant, String>]
        #
        def scope_by_specs
          grouped_variants = group_by(&:specs)
          all_spec_variants = grouped_variants.map { |set| set.variants.first.specs }
          common_specs = all_spec_variants.reduce(all_spec_variants.first, &:&)
          scope_if_necessary(grouped_variants.map(&:scope_by_build_type)) do |variant|
            subspecs = variant.specs - common_specs
            subspec_names = subspecs.map do |spec|
              spec.root? ? 'root' : spec.name.split('/')[1..-1].join('_')
            end.sort
            subspec_names.empty? ? nil : subspec_names.join('-')
          end
        end

        # @private
        #
        # Helps to define scope suffixes recursively.
        #
        # @return [Hash<PodVariant, String>]
        #
        def scope_without_suffix
          Hash[variants.map { |v| [v, nil] }]
        end
      end
    end
  end
end
