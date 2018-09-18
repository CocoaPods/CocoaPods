Feature name
------------

* Authors: [Author 1](https://github.com/CocoaPods), [Author 2](https://github.com/CocoaPods)
* Status: **Awaiting implementation**
* Target CocoaPods Version: **1.0.0**

## Background

A short description of what the feature is. Try to keep it to a
single-paragraph "elevator pitch" so the reader understands what
problem this proposal is addressing.

## Design

Describe the design of the solution in detail. If it's a new API, show the full
API and its documentation comments detailing what it does. The detail
in this section should be sufficient for someone who is *not* one of the
authors to be able to reasonably implement the feature.

### DSL Changes

Describe and show potential DSL changes that could take place with the feature
you are implementing. This should show the before and after of the changes and
describe the necessity for making these changes.

```ruby
# dsl.rb

# @!method new_feature=(version)
#
#   A new feature that I am putting in.
#
#   @example
#
#     spec.new_feature = 'Something'
#
#   @param  [String] new_feature
#
attribute :new_feature,
          :required => false
```

```ruby
# Podspec implementing new feature.

Pod::Spec.new do |s|
  s.name         = "Feature1"
  s.version      = "1.1.0"
  s.new_feature  = "SomeNewFeature"
end
```



### Validation

Describe the validation strategy if needed to ensure this feature is in the
correct state when trying to run cocoapods.

### Backwards Compatibility

Features should have backwards compatibility with older versions of CocoaPods to
ensure upgradability of projects. If this is going to be a breaking change
without backwards compatibility it should be explicitly called out here with
reasoning, possible future ramifications, and ways forward for upgrading.

## Alternatives considered

Describe alternative approaches to addressing the same problem, and
why you chose this approach instead.
