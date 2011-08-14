module SpecHelper
  def self.fixture(name)
    Fixture.fixture(name)
  end

  module Fixture
    ROOT = File.join(::ROOT, 'spec', 'fixtures')

    def fixture(name)
      File.join(ROOT, name)
    end
    module_function :fixture
  end
end
