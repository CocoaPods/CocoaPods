require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  class Command
    class Lib
      describe Create do
        before do
          @create = Create.new(CLAide::ARGV.new(['libname']))
        end

        it 'passes the Pod::VERSION when there is a configure script' do
          Dir.mktmpdir do |dir|
            Dir.chdir(dir) do
              Dir.mkdir('libname')
              File.write('libname/configure', '')
              @create.expects(:system).with({ 'COCOAPODS_VERSION' => Pod::VERSION }, './configure', 'libname', nil)
              @create.send(:configure_template)
            end
          end
        end
      end
    end
  end
end
