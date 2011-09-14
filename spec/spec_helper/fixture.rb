module SpecHelper
  def self.fixture(name)
    Fixture.fixture(name)
  end

  module Fixture
    ROOT = ::ROOT + 'spec/fixtures'

    def fixture(name)
      ROOT + name
    end
    module_function :fixture
  end
end
