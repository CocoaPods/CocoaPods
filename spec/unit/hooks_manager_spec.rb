require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe HooksManager do
    before do
      @hooks_manager = Pod::HooksManager
      @hooks_manager.instance_variable_set(:@registrations, nil)
    end

    describe 'register' do
      it 'allows to register a block for a notification with a given name' do
        @hooks_manager.register('plugin', :post_install) {}
        @hooks_manager.registrations[:post_install].count.should == 1
        hook = @hooks_manager.registrations[:post_install].first
        hook.class.should == HooksManager::Hook
        hook.name.should == :post_install
        hook.plugin_name.should == 'plugin'
      end

      it 'raises if no name is given' do
        should.raise ArgumentError do
          @hooks_manager.register('name', nil) {}
        end
      end

      it 'raises if no block is given' do
        should.raise ArgumentError do
          @hooks_manager.register('name', :post_install)
        end
      end

      it 'raises if no plugin name is given' do
        should.raise ArgumentError do
          @hooks_manager.register(nil, :post_install) {}
        end
      end
    end

    describe 'run' do
      it 'invokes the hooks' do
        @hooks_manager.register('plugin', :post_install) do |_options|
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
        @hooks_manager.register('plugin', :post_install) do |_options|
          true.should.be.true
        end
        should.not.raise do
          @hooks_manager.run(:pre_install, Object.new)
        end
      end

      it 'only runs hooks from the allowed plugins' do
        @hooks_manager.register('plugin', :post_install) do |_options|
          raise 'Should not be called'
        end

        should.not.raise do
          @hooks_manager.run(:post_install, Object.new, 'plugin2' => {})
        end
      end

      it 'passed along user-specified options when the hook block has arity 2' do
        @hooks_manager.register('plugin', :post_install) do |_options, user_options|
          user_options['key'].should == 'value'
        end

        should.not.raise do
          @hooks_manager.run(:post_install, Object.new, 'plugin' => { 'key' => 'value' })
        end
      end

      it 'passes along user-specified options as hashes with indifferent access' do
        run_count = 0
        @hooks_manager.register('plugin', :post_install) do |_options, user_options|
          user_options['key'].should == 'value'
          user_options[:key].should == 'value'
          run_count += 1
        end

        @hooks_manager.run(:post_install, Object.new, 'plugin' => { 'key' => 'value' })
        @hooks_manager.run(:post_install, Object.new, 'plugin' => { :key => 'value' })
        run_count.should == 2
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

      it 'prints a message in verbose mode when any hooks are run' do
        config.verbose = true
        @hooks_manager.register('plugin', :post_install) {}
        @hooks_manager.run(:post_install, Object.new)
        UI.output.should.match /- Running post install hooks/
      end

      it 'prints a message in verbose mode for each hook run' do
        config.verbose = true
        @hooks_manager.register('plugin', :post_install) {}
        @hooks_manager.run(:post_install, Object.new)
        UI.output.should.include "- plugin from `#{__FILE__}`"
      end
    end
  end
end
