# Don't let testing shortcuts get into master by accident

(modified_files + added_files - %w(Dangerfile)).each do |file|
  contents = File.read(file)
  if file.start_with?('spec')
    fail("`fit` left in tests (#{file})") if contents =~ /fit/
    fail("`fdescribe` left in tests (#{file})") if contents =~ /fdescribe/
  end
end
