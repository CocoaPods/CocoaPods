require 'yaml'

class Hash
  # Replacing the to_yaml function so it'll serialize hashes sorted (by their keys)
  #
  # Original function is in /usr/lib/ruby/1.8/yaml/rubytypes.rb
  def to_yaml( opts = {} )
    YAML::quick_emit( object_id, opts ) do |out|
      out.map( taguri, to_yaml_style ) do |map|
        sort.each do |k, v|   # <-- here's my addition (the 'sort')
          map.add( k, v )
        end
      end
    end
  end
end

module Pod
  class Source

    # Returns metadata of a repo.
    #
    class Metadata

      attr_reader :data_file, :data, :source

      def initialize(source, file = nil)
        @source    = source
        @data_file = file || @source.repo + "metadata.yml"
        @data      = @data_file.exist? ? YAML::load(@data_file.read) : {}
      end

      # Returns an hash in the format [Set.name] = Time
      #
      def creation_dates
        update_creation_dates
        @data[:creation_dates]
      end

      # Compute the creation date as the first time a pod was inserted in the
      # master branch. The computation is incremental as it is expensive.
      #
      def update_creation_dates
        dates = @data[:creation_dates] || {}
        sets  = @source.pod_sets.reject { |set| dates[set.name] != nil }
        Dir.chdir(@source.repo) do
          sets.each do |set|
            puts "[D] set.name".magenta
            # `--first-parent' ensures that results come from the master branch
            #
            date = Time.at(`git log --first-parent --format=%ct #{set.name}`.split("\n").last.to_i)
            dates[set.name] = date
          end
        end
        @data[:creation_dates] = dates
        save_metadata
      end

      # Saves the metadata
      #
      def save_metadata
        File.open(@data_file, 'w') { |f| f.write(YAML::dump(@data)) }
      end
    end
  end
end

