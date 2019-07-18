require 'fileutils'
require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe CDNSource do
    before do
      def get_canonical_file(relative_path)
        path = @remote_dir.join(relative_path)
        File.read(path)
      end

      def get_etag(relative_path)
        path = @source.repo.join(relative_path)
        etag_path = path.sub_ext(path.extname + '.etag')
        File.read(etag_path) if File.exist?(etag_path)
      end

      def all_local_files
        [@source.repo.join('**/*.yml'), @source.repo.join('**/*.txt'), @source.repo.join('**/*.json')].map(&Pathname.method(:glob)).flatten
      end

      def save_url(url)
        @url = url
        File.open(@path.join('.url'), 'w') { |f| f.write(url) }
      end

      def cleanup
        Pathname.glob(@path.join('*')).each(&:rmtree)
        @path.join('.url').delete if @path.join('.url').exist?
      end

      @remote_dir = fixture('mock_cdn_repo_remote')

      @path = fixture('spec-repos-core/test_cdn_repo_local')
      cleanup
      save_url('http://localhost:4321/')

      @source = CDNSource.new(@path)
    end

    after do
      cleanup
    end

    #-------------------------------------------------------------------------#

    describe 'In general' do
      it 'return its name' do
        @source.name.should == 'test_cdn_repo_local'
      end

      it 'return its type' do
        @source.type.should == 'CDN'
      end

      it 'works when the root URL has a trailing slash' do
        save_url('http://localhost:4321/')
        @source = CDNSource.new(@path)
        @source.url.should == 'http://localhost:4321/'
      end

      it 'works when the root URL has a trailing path' do
        save_url('http://localhost:4321/trail/ing/path/')
        @source = CDNSource.new(@path)
        @source.url.should == 'http://localhost:4321/trail/ing/path/'
      end

      it 'works when the root URL has no trailing slash' do
        save_url('http://localhost:4321')
        @source = CDNSource.new(@path)
        @source.url.should == 'http://localhost:4321/'
      end

      it 'works when the root URL file has a newline' do
        save_url("http://localhost:4321/\n")
        @source = CDNSource.new(@path)
        @source.url.should == 'http://localhost:4321/'
      end
    end

    #-------------------------------------------------------------------------#

    describe '#pods' do
      it 'returns the available Pods' do
        @source.pods.should == %w(BeaconKit SDWebImage)
      end

      it "raises if the repo doesn't exist" do
        path = fixture('spec-repos-core/non_existing')
        @source = CDNSource.new(path)
        @source.metadata.should.be.nil?
      end
    end

    #-------------------------------------------------------------------------#

    describe '#versions' do
      it 'returns the available versions of a Pod' do
        @source.versions('BeaconKit').map(&:to_s).should == %w(1.0.5 1.0.4 1.0.3 1.0.2 1.0.1 1.0.0)
      end

      it 'returns nil if the Pod could not be found' do
        @source.versions('Unknown_Pod').should.be.nil
      end

      it 'does not error when a Pod name need URI escaping' do
        @source.versions('СерафимиМногоꙮчитїи').map(&:to_s).should == %w(1.0.0)
        @source.specification('СерафимиМногоꙮчитїи', '1.0.0').name.should == 'СерафимиМногоꙮчитїи'
      end

      it 'handles redirects' do
        relative_path = 'Specs/2/0/9/BeaconKit/1.0.0/BeaconKit.podspec.json'
        podspec = get_canonical_file(relative_path)
        original_url = 'http://localhost:4321/' + relative_path
        redirect_url = 'http://localhost:4321/redirected/' + relative_path
        REST.expects(:get).
          with(original_url).
          returns(REST::Response.new(301, 'location' => [redirect_url]))
        REST.expects(:get).
          with(redirect_url).
          returns(REST::Response.new(200, {}, podspec))

        @source.expects(:debug).with("CDN: #{@source.name} Redirecting from #{original_url} to #{redirect_url}")
        @source.expects(:debug).with { |cmd| cmd =~ /CDN: #{@source.name} Relative path downloaded: #{Regexp.quote(relative_path)}, save ETag:/ }
        @source.specification('BeaconKit', '1.0.0')
      end

      it 'raises if unexpected HTTP error' do
        REST.expects(:get).returns(REST::Response.new(500))
        should.raise Informative do
          @source.specification('BeaconKit', '1.0.0')
        end.message.
          should.include "CDN: #{@source.name} URL couldn\'t be downloaded: #{@url}Specs/2/0/9/BeaconKit/1.0.0/BeaconKit.podspec.json Response: 500"
      end

      it 'raises if unexpected non-HTTP error' do
        REST.expects(:get).at_least_once.raises(Errno::ECONNREFUSED)
        should.raise Informative do
          @source.specification('BeaconKit', '1.0.0')
        end.message.
          should.include "CDN: #{@source.name} URL couldn\'t be downloaded: #{@url}Specs/2/0/9/BeaconKit/1.0.0/BeaconKit.podspec.json, error: #{Errno::ECONNREFUSED.new}"
      end

      it 'retries after unexpected non-HTTP error' do
        real_podspec = File.read(@remote_dir.join(*%w(Specs 2 0 9 BeaconKit 1.0.0 BeaconKit.podspec.json)))
        REST.expects(:get).
          with('http://localhost:4321/Specs/2/0/9/BeaconKit/1.0.0/BeaconKit.podspec.json').
          at_most(2).
          raises(Errno::ECONNREFUSED).
          then.
          returns(REST::Response.new(200, {}, real_podspec))

        spec = @source.specification('BeaconKit', '1.0.0')
        spec.name.should == 'BeaconKit'
      end

      it 'raises cumulative error when more than one Future rejects' do
        REST.expects(:get).
          with('http://localhost:4321/all_pods_versions_2_0_9.txt').
          returns(REST::Response.new(200, {}, 'BeaconKit/1.0.0/1.0.1/1.0.2/1.0.3/1.0.4/1.0.5'))
        versions = %w(0 1 2 3 4 5)
        messages = versions.map do |index|
          REST.expects(:get).
            at_least_once.
            with("http://localhost:4321/Specs/2/0/9/BeaconKit/1.0.#{index}/BeaconKit.podspec.json").
            raises(Errno::ECONNREFUSED)
          "CDN: #{@source.name} URL couldn't be downloaded: #{@url}Specs/2/0/9/BeaconKit/1.0.#{index}/BeaconKit.podspec.json, error: #{Errno::ECONNREFUSED.new}"
        end

        should.raise Informative do
          @source.versions('BeaconKit')
        end.message.should.include "CDN: #{@source.name} Repo update failed - 6 error(s):\n" + messages.join("\n")
      end

      it 'returns cached versions for a Pod' do
        pod_path_children = %w(1.0.5 1.0.4 1.0.3 1.0.2 1.0.1 1.0.0)
        @source.versions('BeaconKit').map(&:to_s).should == pod_path_children
        @source.expects(:download_file).never
        @source.versions('BeaconKit').map(&:to_s).should == pod_path_children
        pod_versions = pod_path_children.map { |v| Version.new(v) }
        @source.instance_variable_get(:@versions_by_name).should == { 'BeaconKit' => pod_versions }
      end
    end

    #-------------------------------------------------------------------------#

    describe '#specification' do
      it 'returns the specification for the given name and version' do
        spec = @source.specification('BeaconKit', Version.new('1.0.5'))
        spec.name.should == 'BeaconKit'
        spec.version.should.to_s == '1.0.5'
      end
    end

    #-------------------------------------------------------------------------#

    describe '#all_specs' do
      it 'raises an error' do
        should.raise Informative do
          @source.all_specs
        end.message.should.match /Can't retrieve all the specs for a CDN-backed source, it will take forever/
      end
    end

    #-------------------------------------------------------------------------#

    describe '#set' do
      it 'returns the set of a given Pod' do
        set = @source.set('BeaconKit')
        set.name.should == 'BeaconKit'
        set.sources.should == [@source]
      end
    end

    #-------------------------------------------------------------------------#

    describe '#pod_sets' do
      it 'raises an error' do
        should.raise Informative do
          @source.pod_sets
        end.message.should.match /Can't retrieve all the pod sets for a CDN-backed source, it will take forever/
      end
    end

    #-------------------------------------------------------------------------#

    describe '#search' do
      it 'searches for the Pod with the given name' do
        @source.search('BeaconKit').name.should == 'BeaconKit'
      end

      it 'searches for the pod with the given dependency' do
        dep = Dependency.new('BeaconKit')
        @source.search(dep).name.should == 'BeaconKit'
      end

      it 'supports dependencies on subspecs' do
        dep = Dependency.new('SDWebImage/MapKit')
        @source.search(dep).name.should == 'SDWebImage'
      end

      it 'matches case' do
        @source.expects(:debug).with { |cmd| cmd =~ /CDN: #{@source.name} Relative path downloaded: all_pods_versions_9_5_b\.txt, save ETag:/ }
        @source.search('bEacoNKIT').should.be.nil?
      end

      describe '#search_by_name' do
        it 'properly configures the sources of a set in search by name' do
          sets = @source.search_by_name('beacon')
          sets.count.should == 1
          set = sets.first
          set.name.should == 'BeaconKit'
          set.sources.map(&:name).should == %w(test_cdn_repo_local)
        end

        it 'can use regular expressions' do
          sets = @source.search_by_name('be{0,1}acon')
          sets.first.name.should == 'BeaconKit'
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe '#search_by_name' do
      it 'does not support full-text search' do
        should.raise Informative do
          @source.search_by_name('beacon', true)
        end.message.should.match /Can't perform full text search, it will take forever/
      end
    end

    #-------------------------------------------------------------------------#

    describe '#fuzzy_search' do
      it 'is case insensitive' do
        @source.fuzzy_search('beaconkit').name.should == 'BeaconKit'
      end

      it 'matches misspells' do
        @source.fuzzy_search('baconkit').name.should == 'BeaconKit'
      end

      it 'matches suffixes' do
        @source.fuzzy_search('Kit').name.should == 'BeaconKit'
      end

      it 'returns nil if there is no match' do
        @source.fuzzy_search('12345').should.be.nil
      end

      it 'matches abbreviations' do
        @source.fuzzy_search('BKit').name.should == 'BeaconKit'
      end
    end

    #-------------------------------------------------------------------------#

    describe '#update' do
      it 'returns empty array' do
        CDNSource.any_instance.expects(:download_file).with('CocoaPods-version.yml').returns('CocoaPods-version.yml')
        @source.update(true).should == []
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Representations' do
      it 'does not support hash representation' do
        should.raise Informative do
          @source.to_hash
        end.message.should.match /Can't retrieve all the specs for a CDN-backed source, it will take forever/
      end

      it 'does not support yaml representation' do
        should.raise Informative do
          @source.to_yaml
        end.message.should.match /Can't retrieve all the specs for a CDN-backed source, it will take forever/
      end
    end

    describe 'with non-empty prefix lengths' do
      describe '#specification_path' do
        it 'returns the path of a specification' do
          path = @source.specification_path('BeaconKit', '1.0.5')
          path.to_s.should.end_with?('Specs/2/0/9/BeaconKit/1.0.5/BeaconKit.podspec.json')
        end
      end
    end

    describe 'with cached files' do
      before do
        @source.search('BeaconKit')
      end

      it 'refreshes all index files' do
        @source.expects(:download_file).with('CocoaPods-version.yml').returns('CocoaPods-version.yml')
        @source.expects(:download_file).with('all_pods_versions_2_0_9.txt').returns('all_pods_versions_2_0_9.txt')

        ['BeaconKit/1.0.0/1.0.1/1.0.2/1.0.3/1.0.4/1.0.5', 'SDWebImage/2.4/2.5/2.6/2.7/2.7.4/3.0/3.1/4.0.0/4.0.0-beta/4.0.0-beta2'].each do |row|
          row = row.split('/')
          pod = row.shift
          versions = row

          next unless pod == 'BeaconKit'

          versions.each do |version|
            podspec_relative_path = @source.pod_path(pod).relative_path_from(@source.repo).join(version).join("#{pod}.podspec.json").to_s
            @source.expects(:download_file).with(podspec_relative_path).returns(podspec_relative_path)
          end
        end
        @source.update(true)
      end

      it 'handles ETag and If-None-Match headers' do
        @source = CDNSource.new(@path)
        all_local_files.each do |path|
          relative_path = path.relative_path_from(@source.repo)
          @source.expects(:debug).with { |cmd| cmd == "CDN: #{@source.name} Relative path: #{relative_path}, has ETag? #{get_etag(path)}" }
          @source.expects(:debug).with { |cmd| cmd == "CDN: #{@source.name} Relative path not modified: #{relative_path}" }
        end
        @source.update(true)
      end
    end
  end
end
