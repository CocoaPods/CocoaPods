require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe UI do
    describe '#section' do
      # TODO
    end

    describe '#titled_section' do
      # TODO
    end

    describe '#title' do
      # TODO
    end

    describe '#message' do
      # TODO
    end

    describe '#info' do
      # TODO
    end

    describe '#notice' do
      # TODO
    end

    describe '#labeled' do

      it 'prints nothing if value is nil' do
        UI.labeled('label', nil)
        UI.output.should == ''

      end

      it 'prints label and value on one line if value is not an array' do
        UI.labeled('label', 'value', 12)
        UI.output.should == "- label:    value\n"
      end

      it 'justifies the label' do
        UI.labeled('label', 'value', 30)
        UI.output.should == "- label:#{' ' * 22}value\n" # 22 = 30 - ('- label:'.length)
      end

      it 'justifies the label with default justification' do
        UI.labeled('label', 'value') # defaults to 12
        UI.output.should == "- label:    value\n"
      end

      it 'uses the indentation level' do
        UI.indentation_level = 10
        UI.labeled('label', 'value') # defaults to 12
        UI.output.should == "#{' ' * 10}- label:    value\n"
      end

      it 'prints array values on separate lines, no indentation level' do
        UI.labeled('label', %w(value1), 12)
        UI.output.should == "- label:\n  - value1\n"
      end

      it 'prints array values (1) on separate lines with indentation level' do
        UI.indentation_level = 10
        UI.labeled('label', %w(value1), 12)
        UI.output.should == "#{' ' * 10}- label:\n#{' ' * 12}- value1\n"
      end

      it 'prints array values (3) on separate lines with indentation level' do
        UI.indentation_level = 10
        values = %w(value1 value2 value3)
        UI.labeled('label', values, 12)
        UI.output.should == "#{' ' * 10}- label:\n" + values.map { |v| "#{' ' * 12}- #{v}\n" }.join
      end

    end
  end
end
