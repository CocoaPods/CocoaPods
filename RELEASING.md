### Releasing CocoaPods

#### Environment Setup

1. Clone [Strata](https://github.com/CocoaPods/Strata)
2. Run `rake clone` to setup the repo and all of its submodules.
3. Clone [Rainforest](https://github.com/CocoaPods/Rainforest).
4. Run `gem install postit`
5. Run `rake clone` to setup the repo and all of its submodules. Note that this may take a while.
6. Setup `options.yml` configuration file:
    1. Include option for `strata` pointing to your Strata repo.
    2. Include option for `branch_prefix` to be used then making a release.
    2. Include paths to [Rubygems](https://rubygems.org) & [Bundler](https://bundler.io) if releasing [Molinillo](https://github.com/CocoaPods/Molinillo).

Example `options.yml` file:
```yaml
---
  strata: '~/Development/Strata'
  branch_prefix: 'dnkoutso/'
  rubygems: '~/Development/rubygems' # Optional unless a Molinillo release is required.
  bundler: '~/Development/bundler' # Optional unless a Molinillo release is required.
```

7. Generate a GitHub [access token](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line) with repo permissions and write it to `.github_access_token` file.
8. Make sure [GPG](https://www.gnupg.org) is setup to your GitHub [account](https://github.com/settings/keys).
9. Clone CocoaPods/Specs to Rainforest/Specs if releasing CocoaPods.
10. Get access to the gems you want to publish on [rubygems.org](https://rubygems.org).

#### Executing A Release

1. Open a PR to [CocoaPods](https://github.com/CocoaPods/CocoaPods) that runs `bundle update cocoapods`. Ensure the build passes and is merged. This ensures CocoaPods will work with the new releases of all its dependencies that are about to be released.
2. Run `rake status` to help you figure out which gems need a release.
3. Run `rake pull` to update all repos (after checking out `master` on all of them).
4. Run `rake topological_order > topological_order.txt`.
5. For each gem you want to release, in topological order (go from the top of `topological_order.txt` to the bottom), run:
    1. Check formatting of latest release in the `CHANGELOG.md`.
    2. Run `rake super_release:[REPO_NAME, VERSION]`.
    3. If `super_release` _fails_ for a gem then do the following:
        1. `cd` into the gem directory that failed.
        2. Run `git reset --hard`.
        3. Get the failure fixed, and start over.

WIP
