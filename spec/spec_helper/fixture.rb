module SpecHelper
  def self.fixture(name)
    Fixture.fixture(name)
  end

  module Fixture
    ROOT = ::ROOT + 'spec/fixtures'

    def fixture(name)
      file = ROOT + name
      unless file.exist?
        archive = Pathname.new(file.to_s + '.tar.gz')
        if archive.exist?
          system "cd '#{archive.dirname}' && tar -zxvf '#{archive}' > /dev/null 2>&1"
        end
      end
      file
    end
    module_function :fixture
  end
end
