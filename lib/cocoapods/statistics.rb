require 'json'
require 'rest'
module Pod
  class Statistics

    include Config::Mixin

    public

    def submit_statistics(specs)
      request = REST::Request.new(:post,
                                  install_uri,
                                  json_body(specs), 
                                  @request_options)
      request.perform
    end

    private
    @request_options = {'Content-Type' => 'application/json; charset=utf-8'}

    def json_body(specs)
      body = {}
      specs.each do |spec|
        spec_data = spec.source
        spec_data["version"] = spec.version

        body[spec.name] = spec_data
      end
      body.to_json
    end

    def install_uri
      URI.join(config.stat_server, "/installs")
    end

  end
end
