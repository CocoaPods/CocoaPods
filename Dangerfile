# Don't let testing shortcuts get into master by accident

(modified_files + added_files - %w(Dangerfile)).each do |file|
  next unless File.file?(file)
  contents = File.read(file)
  if file.start_with?('spec')
    fail("`xit` or `fit` left in tests (#{file})") if contents =~ /^\w*[xf]it/
    fail("`fdescribe` left in tests (#{file})") if contents =~ /^\w*fdescribe/
  end
end

if commits.any? { |c| c.message =~ /^Merge branch '#{branch_for_merge}'/ }
  fail("Please rebase to get rid of the merge commits in this PR")
end
