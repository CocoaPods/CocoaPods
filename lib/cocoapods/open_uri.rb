require 'open-uri'
#
# From: https://gist.github.com/1271420
#
# Allow open-uri to follow unsafe redirects (i.e. https to http).
# Relevant issue:
# http://redmine.ruby-lang.org/issues/3719
# Source here:
# https://github.com/ruby/ruby/blob/trunk/lib/open-uri.rb
module OpenURI
  class <<self
    alias_method :open_uri_original, :open_uri
    alias_method :redirectable_cautious?, :redirectable?

    def redirectable_baller? uri1, uri2
      valid = /\A(?:https?|ftp)\z/i
      valid =~ uri1.scheme.downcase && valid =~ uri2.scheme
    end
  end

  # The original open_uri takes *args but then doesn't do anything with them.
  # Assume we can only handle a hash.
  def self.open_uri name, options = {}, &block
    value = options.delete :allow_unsafe_redirects

    if value
      class <<self
        remove_method :redirectable?
        alias_method :redirectable?, :redirectable_baller?
      end
    else
      class <<self
        remove_method :redirectable?
        alias_method :redirectable?, :redirectable_cautious?
      end
    end

    self.open_uri_original name, options, &block
  end
end
