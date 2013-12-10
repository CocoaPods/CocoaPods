require 'net/http'
module Pod
  class Statistics

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
      Net::HTTP.new("localhost",4567)
    end

    def submit_install_request
      Net::HTTP::Post.new("/install")
    end
  end
end
