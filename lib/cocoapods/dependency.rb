module Gem
end
require 'rubygems/dependency'

module Pod
  class Dependency < Gem::Dependency
    attr_accessor :only_part_of_other_pod
    alias_method :only_part_of_other_pod?, :only_part_of_other_pod

    attr_accessor :external_spec_source

    attr_accessor :specification

    def initialize(*name_and_version_requirements, &block)
      if name_and_version_requirements.empty? && block
        @specification = Specification.new(&block)
        super(@specification.name, @specification.version)

      elsif !name_and_version_requirements.empty? && block.nil?
        if name_and_version_requirements.last.is_a?(Hash)
          @external_spec_source = name_and_version_requirements.pop
        end
        super(name_and_version_requirements.first)

      else
        raise Informative, "A dependency needs either a name and version requirements, " \
                           "a source hash, or a block which defines a podspec."
      end
      @only_part_of_other_pod = false
    end

    def ==(other)
      super &&
        @only_part_of_other_pod == other.only_part_of_other_pod &&
          @external_spec_source == other.external_spec_source &&
                 @specification == other.specification
    end

    def external_podspec?
      !@external_spec_source.nil?
    end

    def inline_podspec?
      !@specification.nil?
    end

    def specification
      @specification ||= begin
        # This is an external podspec
        pod_root = Config.instance.project_pods_root + @name
        downloader = Downloader.for_source(pod_root, @external_spec_source)
        downloader.download
        file = pod_root + "#{@name}.podspec"
        Specification.from_file(file)
      end
    end

    # Taken from a newer version of RubyGems
    unless public_method_defined?(:merge)
      def merge other
        unless name == other.name then
          raise ArgumentError,
                "#{self} and #{other} have different names"
        end

        default = Gem::Requirement.default
        self_req  = self.requirement
        other_req = other.requirement

        return self.class.new name, self_req  if other_req == default
        return self.class.new name, other_req if self_req  == default

        self.class.new name, self_req.as_list.concat(other_req.as_list)
      end
    end

  end
end
