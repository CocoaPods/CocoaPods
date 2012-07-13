module Gem
end
require 'rubygems/version'

module Pod
  class Version < Gem::Version
    attr_accessor :head
    alias_method :head?, :head
  end
end

