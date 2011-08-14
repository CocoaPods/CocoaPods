require 'fileutils'

module SpecHelper
  def self.temporary_directory
    TemporaryDirectory.temporary_directory
  end

  module TemporaryDirectory
    def temporary_directory
      File.join(ROOT, 'tmp')
    end
    module_function :temporary_directory
    
    def setup_temporary_directory
      FileUtils.mkdir_p(temporary_directory)
    end
    
    def teardown_temporary_directory
      FileUtils.rm_rf(temporary_directory)
    end
    
    def self.extended(base)
      base.before do
        teardown_temporary_directory
        setup_temporary_directory
      end
    end
  end
end
