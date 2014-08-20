require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe HooksManager do
    before do
      @hooks_manager = Pod::HooksManager
    end

    describe 'register' do
      it 'allows to register a block for a notification with a given name' do
        @hooks_manager.register(:post_install) {}
        @hooks_manager.registrations[:post_install].count.should == 1
        @hooks_manager.registrations[:post_install].first.class.should == Proc
      end

      it 'raises if no name is given' do
        should.raise ArgumentError do
          @hooks_manager.register(nil) {}
        end
      end

      it 'raises if no block is given' do
        should.raise ArgumentError do
          @hooks_manager.register(:post_install)
        end
      end
    end

    describe 'run' do
      it 'invokes the hooks' do
        @hooks_manager.register(:post_install) do |_options|
          true.should.be.true
        end
        @hooks_manager.run(:post_install, Object.new)
      end

      it 'handles the case that no listeners have registered' do
        should.not.raise do
          @hooks_manager.run(:post_install, Object.new)
        end
      end

      it 'handles the case that no listeners have registered for a name' do
        @hooks_manager.register(:post_install) do |_options|
          true.should.be.true
        end
        should.not.raise do
          @hooks_manager.run(:pre_install, Object.new)
        end
      end

      it 'raises if no name is given' do
        should.raise ArgumentError do
          @hooks_manager.run(nil, Object.new) {}
        end
      end

      it 'raises if no context object is given' do
        should.raise ArgumentError do
          @hooks_manager.run(:post_install, nil)
        end
      end
    end
  end
end
