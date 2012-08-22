require 'open-uri'

# Inspiration from: https://gist.github.com/1271420
#
# Allow open-uri to follow http to https redirects.
# Relevant issue:
# http://redmine.ruby-lang.org/issues/3719
# Source here:
# https://github.com/ruby/ruby/blob/trunk/lib/open-uri.rb

module OpenURI
  def OpenURI.redirectable?(uri1, uri2) # :nodoc:
    # This test is intended to forbid a redirection from http://... to
    # file:///etc/passwd, file:///dev/zero, etc.  CVE-2011-1521
    # https to http redirect is also forbidden intentionally.
    # It avoids sending secure cookie or referer by non-secure HTTP protocol.
    # (RFC 2109 4.3.1, RFC 2965 3.3, RFC 2616 15.1.3)
    # However this is ad hoc.  It should be extensible/configurable.
    uri1.scheme.downcase == uri2.scheme.downcase ||
    (/\A(?:http|ftp)\z/i =~ uri1.scheme && /\A(?:https?|ftp)\z/i =~ uri2.scheme)
  end
end
