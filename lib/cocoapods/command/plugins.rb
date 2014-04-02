require 'open-uri'
require 'json'

module Pod
  class Command
    class Plugins < Command
      attr_accessor :json

      self.summary = 'Show available CocoaPods plugins'

      self.description = <<-DESC
        Shows the available CocoaPods plugins and if you have them installed or not.
      DESC

      def download_json
        response = open('https://raw.githubusercontent.com/CocoaPods/cocoapods.org/master/data/plugins.json')
        @json = JSON.parse(response.read)
      end
      
      def gem_available?(gemname)
        if Gem::Specification.methods.include?(:find_all_by_name) 
          Gem::Specification.find_all_by_name(gemname).any?
        else
          # Fallback to Gem.available? for old versions of rubygems
          Gem.available?(gemname)
        end
       end

      def is_installed?(gemname)
        return Gem::Specification::find_all_by_name(gemname).any?
      end

      def run
        UI.puts "Downloading Plugins list..."
        begin
          download_json unless json
        rescue => e
          UI.puts e.message
        end

        if !json
          UI.puts "Could not download plugins list from cocoapods.org"
        else
          UI.puts "Available CocoaPods Plugins\n\n"

          @json['plugins'].each do |plugin|
            UI.puts "Name: #{plugin['name']}"

            if is_installed?(plugin['gem'])
              UI.puts "Gem: #{plugin['gem']}".green
            else
              UI.puts "Gem: #{plugin['gem']}".yellow
            end

            UI.puts "URL: #{plugin['url']}"
            UI.puts "\n#{plugin['description']}\n\n"
          end
        end
      end

    end
  end
end


