require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  class Target
    describe BuildType do
      describe '#initialize' do
        it 'returns static library by default' do
          BuildType.new.should == BuildType.static_library
        end

        it 'allows specifying linkage' do
          BuildType.new(:linkage => :dynamic).should == BuildType.dynamic_library
        end

        it 'allows specifying packaging' do
          BuildType.new(:packaging => :framework).should == BuildType.static_framework
        end

        it 'raises when given an unknown linkage' do
          -> { BuildType.new(:linkage => :foo) }.should.raise(ArgumentError).
            message.should.include? 'Invalid linkage option :foo, valid options are [:static, :dynamic]'
        end
      end

      describe 'convenience factory methods' do
        it '#dynamic_library' do
          BuildType.dynamic_library.should == BuildType.new(:linkage => :dynamic, :packaging => :library)
        end

        it '#static_library' do
          BuildType.static_library.should == BuildType.new(:linkage => :static, :packaging => :library)
        end

        it '#dynamic_framework' do
          BuildType.dynamic_framework.should == BuildType.new(:linkage => :dynamic, :packaging => :framework)
        end

        it '#static_framework' do
          BuildType.static_framework.should == BuildType.new(:linkage => :static, :packaging => :framework)
        end
      end

      describe '.infer_from_spec' do
        it 'infers the build type' do
          BuildType.infer_from_spec(nil, :host_requires_frameworks => false).should == BuildType.static_library
          BuildType.infer_from_spec(nil, :host_requires_frameworks => true).should == BuildType.dynamic_framework

          BuildType.infer_from_spec(stub('spec', :root => stub('root_spec', :static_framework => true)), :host_requires_frameworks => false).
            should == BuildType.static_library
          BuildType.infer_from_spec(stub('spec', :root => stub('root_spec', :static_framework => false)), :host_requires_frameworks => false).
            should == BuildType.static_library
          BuildType.infer_from_spec(stub('spec', :root => stub('root_spec', :static_framework => true)), :host_requires_frameworks => true).
            should == BuildType.static_framework
          BuildType.infer_from_spec(stub('spec', :root => stub('root_spec', :static_framework => false)), :host_requires_frameworks => true).
            should == BuildType.dynamic_framework
        end
      end

      describe '#==' do
        it 'compares equal build types as equal' do
          BuildType.new(:linkage => :dynamic, :packaging => :library).should == BuildType.new(:linkage => :dynamic, :packaging => :library)
        end

        it 'compares unequal build types as unequal' do
          BuildType.new(:linkage => :dynamic, :packaging => :framework).should != BuildType.new(:linkage => :dynamic, :packaging => :library)
          BuildType.new(:linkage => :static, :packaging => :library).should != BuildType.new(:linkage => :dynamic, :packaging => :library)
        end
      end

      describe '#to_s' do
        it 'returns a readable representation' do
          BuildType.static_framework.to_s.should == 'static framework'
        end
      end
    end
  end
end
