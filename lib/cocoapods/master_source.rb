module Pod
  # Is a subclass of Source specific to the master repo.
  class MasterSource < Source
    # @!group Updating the source
    #-------------------------------------------------------------------------#

    # Updates the local clone of the source repo.
    #
    # @param  [Bool] show_output
    #
    # @return  [Array<String>] changed_spec_paths
    #          Returns the list of changed spec paths.
    #
    def update(show_output)
      if requires_update
        super
      else
        []
      end
    end

    # Returns whether a source requires updating. 
    #
    # This will return true for all repos other than master, where we check 
    # to see if there have been new commits via the API. 
    #
    # @param [Source] source
    #        The source to check.
    #
    # @return [Bool] Whether the given source should be updated.
    #
    def requires_update
      current_commit_hash = '""'
      Dir.chdir(repo) do
        current_commit_hash = "\"#{(`git rev-parse HEAD`).strip}\""
      end
      uri = URI.parse('https://api.github.com/repos/CocoaPods/Specs/commits/master')

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      headers = {
        'Accept' => 'application/vnd.github.chitauri-preview+sha',
        'If-None-Match' => current_commit_hash
      }
      code = http.head(uri.path, headers).code.to_i

      return code != 304
    end
  end
end
