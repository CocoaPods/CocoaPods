# Don't let testing shortcuts get into master by accident

(modified_files + added_files).each do |file|
  fail('fdescribe left in tests') if File.read(file) =~ /fit/
  fail('fit left in tests') if File.read(file) =~ /fdescribe/
end
