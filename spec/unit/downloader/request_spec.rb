require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Downloader::Request do
    before do
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
    end

    #--------------------------------------#

    describe 'Validation' do
      it 'validates request initialization' do
        options = [
          { :spec => nil, :name => nil },
          { :spec => nil, :released => true },
          { :spec => @spec.dup.tap { |s| s.source = nil }, :released => true },
        ]

        options.each do |params|
          should.raise(ArgumentError) { Downloader::Request.new(params) }
        end
      end
    end

    #--------------------------------------#

    describe 'when released_pod? == true' do
      before do
        @request = Downloader::Request.new(:spec => @spec, :released => true)
      end

      it 'returns the spec' do
        @request.spec.should == @spec
      end

      it 'returns whether the pod is released' do
        @request.released_pod?.should == true
      end

      it 'returns the name of the spec' do
        @request.name.should == @spec.name
      end

      it 'returns the source of the spec' do
        @request.params.should == @spec.source
      end

      it 'returns the slug' do
        @request.slug.should == 'Release/BananaLib/1.0-5b1d7'
      end
    end

    #--------------------------------------#

    describe 'when released_pod? == false' do
      before do
        @request = Downloader::Request.new(:name => 'BananaLib', :params => @spec.source)
      end

      it 'returns the spec' do
        @request.spec.should.be.nil?
      end

      it 'returns whether the pod is released' do
        @request.released_pod?.should == false
      end

      it 'returns the name of the spec' do
        @request.name.should == 'BananaLib'
      end

      it 'returns the source of the spec' do
        @request.params.should == @spec.source
      end

      it 'returns the slug' do
        @request.slug.should == 'External/BananaLib/a0856313adccfbcc7c5b0ea859ee14f5'
      end
    end
  end
end
