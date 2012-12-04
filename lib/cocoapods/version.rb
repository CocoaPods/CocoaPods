module Pod
  class Version < Gem::Version
    
    # Conforms to Semantic Versioning by including a hyphen
    VERSION_PATTERN = '[0-9]+(\.[0-9a-zA-Z\-]+)*' # :nodoc:
    ANCHORED_VERSION_PATTERN = /\A\s*(#{VERSION_PATTERN})*\s*\z/ # :nodoc:

    def self.correct? version
      version.to_s =~ ANCHORED_VERSION_PATTERN
    end
    
    # @returns A Version described by its #to_s method.
    #
    # @TODO The `from' part of the regexp should be remove before 1.0.0.
    #
    def self.from_string(string)
      if string =~ /HEAD (based on|from) (.*)/
        v = Version.new($2)
        v.head = true
        v
      else
        Version.new(string)
      end
    end

    attr_accessor :head
    alias_method :head?, :head

    def to_s
      head? ? "HEAD based on #{super}" : super
    end
    
    # Conform to Semantic Versioning instead of RubyGems
    # pre-release gems can contain a hyphen and/or a letter
    def prerelease?
      @prerelease ||= @version =~ /[a-zA-Z\-]/
    end
  end
end

