module Pod
  module Xcode
    class Config
      def initialize(xcconfig_hash = {})
        @attributes = {}
        merge!(xcconfig_hash)
      end

      def merge!(xcconfig_hash)
        xcconfig_hash.each do |key, value|
          if existing_value = @attributes[key]
            @attributes[key] = "#{existing_value} #{value}"
          else
            @attributes[key] = value
          end
        end
      end
      alias_method :<<, :merge!

      def create_in(pods_root)
        (pods_root + 'Pods.xcconfig').open('w') do |file|
          @attributes.each do |key, value|
            file.puts "#{key} = #{value}"
          end
        end
      end
    end
  end
end
