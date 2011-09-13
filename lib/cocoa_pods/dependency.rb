module Gem
end
require 'rubygems/dependency'

module Pod
  class Dependency < Gem::Dependency
    attr_accessor :part_of_other_pod

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
