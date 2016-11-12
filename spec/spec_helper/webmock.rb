require File.expand_path('../../spec_helper', __FILE__)
require 'webmock'

module Bacon
  class Context
    module AfterWebMock
      def after(&block)
        super
        WebMock.reset!
      end
    end

    include AfterWebMock
  end
end
