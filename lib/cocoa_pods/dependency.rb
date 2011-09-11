module Gem
end
require 'rubygems/dependency'

module Pod
  class Dependency < Gem::Dependency
    attr_accessor :part_of_other_pod
  end
end
