# Don't let testing shortcuts get into master by accident,
# ensuring that we don't get green builds based on a subset of tests
(git.modified_files + git.added_files - %w(Dangerfile)).each do |file|
  next unless File.file?(file)
  next unless file =~ /^spec.*\.rb/

  contents = File.read(file)
  fail("`xit` or `fit` left in tests (#{file})") if contents =~ /^\s*[xf]it/
  fail("`fdescribe` left in tests (#{file})") if contents =~ /^\s*fdescribe/
end

# Ensure a clean commits history
if git.commits.any? { |c| c.message =~ /^Merge branch '#{github.branch_for_base}'/ }
  fail('Please rebase to get rid of the merge commits in this PR')
end

# Request a CHANGELOG entry, and give an example
has_app_changes = !git.modified_files.grep(/lib/).empty?
if !git.modified_files.include?('CHANGELOG.md') && has_app_changes
  warn("Please include a CHANGELOG entry to credit yourself! \nYou can find it at [CHANGELOG.md](https://github.com/CocoaPods/CocoaPods/blob/master/CHANGELOG.md).", :sticky => false)
  markdown <<-MARKDOWN
Here's an example of your CHANGELOG entry:

```markdown
* #{github.pr_title}\s\s
  [#{github.pr_author}](https://github.com/#{github.pr_author})
  [#issue_number](https://github.com/CocoaPods/CocoaPods/issues/issue_number)
```

*note*: There are two invisible spaces after the entry's text.
MARKDOWN
end
