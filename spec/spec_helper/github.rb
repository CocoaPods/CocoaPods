module SpecHelper
  module Github
    def expect_github_repo_request(data = nil)
      data ||= {
        "clone_url" => "https://github.com/lukeredpath/libPusher.git",
        "created_at" => "2010-03-22T17:06:16Z",
        "description" => "An Objective-C interface to Pusher (pusherapp.com)",
        "fork" => false,
        "forks" => 22,
        "git_url" => "git://github.com/lukeredpath/libPusher.git",
        "has_downloads" => true,
        "has_issues" => true,
        "has_wiki" => true,
        "homepage" => "",
        "html_url" => "https://github.com/lukeredpath/libPusher",
        "id" => 574304,
        "language" => "C",
        "mirror_url" => nil,
        "name" => "libPusher",
        "open_issues" => 2,
        "owner" => {
          "avatar_url" => "https://secure.gravatar.com/avatar/bdd4d23d1a822b2d68b53e7c51d69a39?d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-140.png",
          "gravatar_id" => "bdd4d23d1a822b2d68b53e7c51d69a39",
          "id" => 613,
          "login" => "lukeredpath",
          "url" => "https://api.github.com/users/lukeredpath"
        },
        "private" => false,
        "pushed_at" => "2012-04-10T13:16:49Z",
        "size" => 3654,
        "ssh_url" => "git@github.com:lukeredpath/libPusher.git",
        "svn_url" => "https://github.com/lukeredpath/libPusher",
        "updated_at" => "2012-04-16T23:01:00Z",
        "url" => "https://api.github.com/repos/lukeredpath/libPusher",
        "watchers" => 143
      }
      Octokit.expects(:repo).with('lukeredpath/libPusher').returns(data)
    end

    def expect_github_tags_request(data = nil)
      data ||= [
        {
          "commit" => {
            "sha" => "ea47899b65db8e9fd77b3a236f602771f15ca28f",
            "url" => "https://api.github.com/repos/lukeredpath/libPusher/commits/ea47899b65db8e9fd77b3a236f602771f15ca28f"
          },
          "name" => "v1.2",
          "tarball_url" => "https://github.com/lukeredpath/libPusher/tarball/v1.2",
          "zipball_url" => "https://github.com/lukeredpath/libPusher/zipball/v1.2"
        },
        {
          "commit" => {
            "sha" => "788468bc173e1bb57646a3ff8ace551df10a4249",
            "url" => "https://api.github.com/repos/lukeredpath/libPusher/commits/788468bc173e1bb57646a3ff8ace551df10a4249"
          },
          "name" => "v1.0.1",
          "tarball_url" => "https://github.com/lukeredpath/libPusher/tarball/v1.0.1",
          "zipball_url" => "https://github.com/lukeredpath/libPusher/zipball/v1.0.1"
        },
        {
          "commit" => {
            "sha" => "d4d51f86dc460c389b9d19c9453541f7daf7076b",
            "url" => "https://api.github.com/repos/lukeredpath/libPusher/commits/d4d51f86dc460c389b9d19c9453541f7daf7076b"
          },
          "name" => "v1.3",
          "tarball_url" => "https://github.com/lukeredpath/libPusher/tarball/v1.3",
          "zipball_url" => "https://github.com/lukeredpath/libPusher/zipball/v1.3"
        },
        {
          "commit" => {
            "sha" => "c4ed3712ad2bee5c9e754339f1860f15daf788f4",
            "url" => "https://api.github.com/repos/lukeredpath/libPusher/commits/c4ed3712ad2bee5c9e754339f1860f15daf788f4"
          },
          "name" => "v1.0",
          "tarball_url" => "https://github.com/lukeredpath/libPusher/tarball/v1.0",
          "zipball_url" => "https://github.com/lukeredpath/libPusher/zipball/v1.0"
        },
        {
          "commit" => {
            "sha" => "77523befd5509f91b8cbe03f45d30e6ce8ab96f4",
            "url" => "https://api.github.com/repos/lukeredpath/libPusher/commits/77523befd5509f91b8cbe03f45d30e6ce8ab96f4"
          },
          "name" => "v1.1",
          "tarball_url" => "https://github.com/lukeredpath/libPusher/tarball/v1.1",
          "zipball_url" => "https://github.com/lukeredpath/libPusher/zipball/v1.1"
        }
      ]
      Octokit.expects(:tags).with(:username => 'lukeredpath', :repo => 'libPusher').returns(data)
    end

    def expect_github_branches_request(data = nil)
      data ||= [
        {
          "commit" => {
            "sha" => "d7aac34e846e2fe9b9da54978abfada8f9aa69a8",
            "url" => "https://api.github.com/repos/lukeredpath/libPusher/commits/d7aac34e846e2fe9b9da54978abfada8f9aa69a8"
          },
          "name" => "use-socketrocket-backend"
        },
        {
          "commit" => {
            "sha" => "daa4ba9398af4b532bfbca610065057e709cc877",
            "url" => "https://api.github.com/repos/lukeredpath/libPusher/commits/daa4ba9398af4b532bfbca610065057e709cc877"
          },
          "name" => "gh-pages"
        },
        {
          "commit" => {
            "sha" => "5f482b0693ac2ac1ad85d1aabc27ec7547cc0bc7",
            "url" => "https://api.github.com/repos/lukeredpath/libPusher/commits/5f482b0693ac2ac1ad85d1aabc27ec7547cc0bc7"
          },
          "name" => "master"
        }
      ]
      Octokit.expects(:branches).with(:username => 'lukeredpath', :repo => 'libPusher').returns(data)
    end

    def expect_github_user_request(data = nil)
      data ||= {
        "avatar_url" => "https://secure.gravatar.com/avatar/bdd4d23d1a822b2d68b53e7c51d69a39?d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-140.png",
        "bio" => "I\342\200\231m a Ruby on Rails and iPhone developer based in London, UK. I\342\200\231ve been writing web apps for almost ten years and in late 2008, I released my first iPhone application.\r\n\r\nSince early 2009, I have worked on a freelance/contract basis, having previously worked at Reevoo as part of one of the best Rails development teams in the country.\r\n\r\nI\342\200\231m also a big fan of open-source software which I both use and contribute to whenever possible. I have contributed to many open-source projects over the years, including Rails, RSpec and more recently, Gemcutter, as well as starting many of my own, including Clickatell, a library for interfacing with the Clickatell SMS gateway and SimpleConfig, a declarative application configuration Rails plugin which was developed whilst working at Reevoo.\r\n\r\nI was the technical reviewer for the SitePoint book \342\200\234Build Your Own Ruby on Rails Applications\342\200\235 and also contributed a recipe to \342\200\234Rails Recipes\342\200\235 by Chad Fowler.",
        "blog" => "http://lukeredpath.co.uk",
        "company" => "LJR Software Limited",
        "created_at" => "2008-02-22T14:36:59Z",
        "email" => "luke@lukeredpath.co.uk",
        "followers" => 195,
        "following" => 10,
        "gravatar_id" => "bdd4d23d1a822b2d68b53e7c51d69a39",
        "hireable" => true,
        "html_url" => "https://github.com/lukeredpath",
        "id" => 613,
        "location" => "London, UK",
        "login" => "lukeredpath",
        "name" => "Luke Redpath",
        "public_gists" => 122,
        "public_repos" => 68,
        "type" => "User",
        "url" => "https://api.github.com/users/lukeredpath"
      }
      Octokit.expects(:user).with('lukeredpath').returns(data)
    end
  end
end

