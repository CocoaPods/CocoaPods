require File.expand_path('../../spec_helper', __FILE__)
require 'webmock'

module Bacon
  class Context
    alias webmock_initialize initialize

    def initialize(name, &block)
      webmock_initialize(name, &block)
      before do
        cdn_repo_response = "---
         min: 1.0.0
         last: #{Pod::VERSION}
         prefix_lengths:
         - 1
         - 1
         - 1
         mock_key: mock_value".freeze
        WebMock.enable!
        WebMock.stub_request(:get, Pod::TrunkSource::TRUNK_REPO_URL + '/CocoaPods-version.yml').
          to_return(:status => 200, :body => cdn_repo_response, :headers => {})
        metadata = Pod::Source::Metadata.new('min' => '1.0.0',
                                             'last' => '1.8.1',
                                             'prefix_lengths' => [1, 1, 1])
        Pod::CDNSource.any_instance.stubs(:metadata).returns(metadata)
      end
      after do
        WebMock.reset!
        WebMock.allow_net_connect!
        WebMock.disable!
      end
    end
  end
end
