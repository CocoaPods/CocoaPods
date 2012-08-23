module Pod
  class Version < Gem::Version

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
  end
end

