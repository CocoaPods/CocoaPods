# Don't let testing shortcuts get into master by accident

(modified_files + added_files - %w(Dangerfile)).each do |file|
  next unless File.file?(file)
  contents = File.read(file)
  if file.start_with?('spec')
    fail("`xit` or `fit` left in tests (#{file})") if contents =~ /^\w*[xf]it/
    fail("`fdescribe` left in tests (#{file})") if contents =~ /^\w*fdescribe/
  end
end

# Ensure a clean commits history
if commits.any? { |c| c.message =~ /^Merge branch '#{branch_for_merge}'/ }
  fail('Please rebase to get rid of the merge commits in this PR')
end

# Request a CHANGELOG entry, and give an example
has_app_changes = !modified_files.grep(/lib/).empty?
if !modified_files.include?('CHANGELOG.md') && has_app_changes
  fail('Please include a CHANGELOG entry to credit yourself! \nYou can find it at [CHANGELOG.md](https://github.com/CocoaPods/CocoaPods/blob/master/CHANGELOG.md).', :sticky => false)
  markdown <<-MARKDOWN
Here's an example of your CHANGELOG entry:

```markdown
* #{pr.title}#{' '}
  [#{pr_author}](https://github.com/#{pr_author})
  [#issue_number](https://github.com/CocoaPods/CocoaPods/issues/issue_number)
```

*note*: There are two invisible spaces after the entry's text.
MARKDOWN
end
