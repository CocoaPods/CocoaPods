module Pod
  module Xcode
    class Config
      def initialize(xcconfig_hash = {})
        @attributes = {}
        merge!(xcconfig_hash)
      end

      def to_hash
        @attributes
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

      def to_s
        @attributes.map { |key, value| "#{key} = #{value}" }.join("\n")
      end

      def create_in(pods_root)
        (pods_root + 'Pods.xcconfig').open('w') { |file| file << to_s }
      end
    end
  end
end
