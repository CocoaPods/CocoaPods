require 'net/http'
require 'uri'
module Pod
  class Statistics

    include Config::Mixin

    public

    def submit_statistics(spec)
      request = submit_install_request
      request.set_form_data form_data(spec)
      http_client.request request
    end

    private

    def form_data(spec)
      form_data = spec.source
      form_data["name"] = spec.name
      form_data["version"] = spec.version
      form_data
    end

    def http_client
      uri = URI.parse config.stat_server
      Net::HTTP.new(uri.host,uri.port)
    end

    def submit_install_request
      Net::HTTP::Post.new("/install")
    end
  end
end
