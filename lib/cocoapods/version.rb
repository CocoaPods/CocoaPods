module Pod
  class Version < Gem::Version

    # @returns A Version described by its #to_s method.
    #
    def self.from_s(string)
      match = string.match(/HEAD from (.*)/)
      string = match[1] if match
      vers = Version.new(string)
      vers.head = true if match
      vers
    end

    attr_accessor :head
    alias_method :head?, :head

    def to_s
      head? ? "HEAD from #{super}" : super
    end
  end
end

