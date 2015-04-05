module Pod
  module Downloader
    Response = Struct.new(:location, :spec, :checkout_options)
  end
end
