# Proposal Title

* Authors: [Author 1](https://github.com/cocoadev1), [Author 2](https://github.com/cocoadev2)

*Add the fields below if applicable*

* Implementation: [CocoaPods/Cocoapods#NNNNN](https://github.com/CocoaPods/CocoaPods/pull/NNNNN)
* Bugs: [CocoaPods/CocoaPods#NNNNN](https://github.com/CocoaPods/CocoaPods/issues/NNNNN)
* Previous RFC: [CocoaPods/Cocoapods#NNNNN](https://github.com/CocoaPods/CocoaPods/issues/NNNNN)

## Introduction

A short description of what the feature is. Try to keep it to a
single-paragraph "elevator pitch" so the reader understands what
problem this proposal is addressing.

## Motivation

Describe the problems that this proposal seeks to address. Does the proposal
impact pod authors, pod consumers, or both? If this feature is possible by other
means such as a plugin or `post_install` hook, explain how this proposal is better
than the other options available.

## Proposed solution

Describe your solution to the problem. Provide examples and describe
how they work. Show how your solution is better than current
workarounds: is it cleaner, safer, or more efficient?

## Detailed design

Describe the design of the solution in detail. If it involves new
DSL for Podfiles or Podspecs, show the additions with examples and
descriptions of the types involved (ex. does the attribute accept any `String`?)

If it's a new plugin API (ex. new plugin hook, or changes to an existing hook context),
show the full API and its documentation comments detailing what it does. The detail in 
this section should be sufficient for someone who is *not* one of the authors to be able to
reasonably implement the feature.

## Backwards compatibility

Describe how this feature will impact users of prior versions of CocoaPods.
If the feature introduces new DSL to Podspecs, projects using older versions of 
CocoaPods may not be able to consume Podspecs that utilize the new DSL. If the feature
introduces changes to the Podfile DSL, downgrading to an older version of CocoaPods may
cause `pod install` to fail. If the feature changes an _existing_ DSL feature, explain 
how this will impact users who are expecting the previous behavior.

Is this feature only applicable to certain versions of Xcode? If so, specify which version(s)
the feature supports and why.

## Alternatives considered

Describe alternative approaches to addressing the same problem, and
why you chose this approach instead.
