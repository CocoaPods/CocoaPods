require 'xcodeproj'
require 'yaml'

class Xcodeproj::Project
  def to_yaml
    pretty_print_output = pretty_print
    sections = []
    sorted_keys = ['File References', 'Targets', 'Build Configurations']
    sorted_keys.each do |key|
      yaml = { key => pretty_print_output[key] }.to_yaml
      sections << yaml
    end
    (sections * "\n\n").gsub!('---', '')
  end
end
