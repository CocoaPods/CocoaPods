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
        return super.update(show_output)
      end

      return []
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
      Dir.chdir(repo) do
        current_commit_hash = (`git rev-parse HEAD`).strip
      end
      url = URI.parse('https://api.github.com/repos/CocoaPods/Specs/commits/master')
      req = Net::HTTP::Get.new(url.path)
      req.add_field('Accept', 'application/vnd.github.chitauri-preview+sha')
      req.add_field('If-None-Match', current_commit_hash)

      res = Net::HTTP.new(url.host, url.port).start do |http|
        http.request(req)
      end

      return res.code != 304 
    end
  end
end
