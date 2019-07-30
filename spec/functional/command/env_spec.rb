require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Command::Env do
    describe 'In general' do
      before do
        @report = Command::Env.new(CLAide::ARGV.new([]))
      end

      it 'returns a well-structured environment report' do
        expected = <<-EOS

#{UI::ErrorReport.stack}
### Installation Source

```
Executable Path: #{@report.send(:actual_path)}
```

### Plugins

```
#{UI::ErrorReport.plugins_string}
```
#{UI::ErrorReport.markdown_podfile}
EOS

        @report.report.should == expected
      end
    end
  end
end
