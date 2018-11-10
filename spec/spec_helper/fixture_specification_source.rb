require_relative 'fixture'

# README!
#
# Override {Specification#source} to return sources from fixtures and limit
# network connections.
#
module Pod
  class Specification
    def source
      fixture = SpecHelper.fixture("integration/#{name}")
      result = super
      result[:git] = fixture.to_s if fixture.exist?
      result
    end
  end
end
