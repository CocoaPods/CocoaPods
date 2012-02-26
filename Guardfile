# A sample Guardfile
# More info at https://github.com/guard/guard#readme

def run_spec(s)
  `bundle exec bacon #{s}`
end

# parameters:
#  output     => the formatted to use
#  backtrace  => number of lines, nil =  everything
guard :shell do
  watch(%r{^lib/cocoapods/(.+)\.rb$}) { |m| run_spec("spec/unit/#{m[1]}_spec.rb") }
  watch(%r{spec/.+\.rb$})             { |s| run_spec(s) }
end

