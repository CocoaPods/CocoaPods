require File.expand_path('../../spec_helper', __FILE__)
require 'webmock'

module Bacon
  class Context
    alias webmock_initialize initialize

    def initialize(name, &block)
      webmock_initialize(name, &block)
      after do
        WebMock.reset!
        WebMock.allow_net_connect!
        WebMock.disable!
      end
    end
  end
end
