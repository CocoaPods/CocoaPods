source "http://rubygems.org"

gem "colored"
gem "escape"
gem "json"
gem "open4"

# We don't want octokit to pull in faraday 0.8.0, as it prints a warning about
# the `system_timer` gem being needed, which isn't available on 1.9.x
#
# Once faraday 0.8.1 is released this should be resolved:
# https://github.com/technoweenie/faraday/pull/147
gem "faraday", "0.7.6"
gem "octokit", "<= 1.0.3"

group :development do
  gem "xcodeproj", :git => "git://github.com/CocoaPods/Xcodeproj.git"

  gem "bacon"
  gem "kicker"
  gem "mocha-on-bacon"
  gem "rake"
  gem "rb-fsevent"
  gem "vcr"
  gem "webmock"
  gem "awesome_print"
  gem "pry"
end
