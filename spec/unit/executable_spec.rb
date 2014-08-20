require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Executable do
    it 'shows the actual command on failure' do
      e = lambda do
        Executable.execute_command('false',
                                   '', true)
      end.should.raise Informative
      e.message.should.match(/false/)
    end
  end
end
