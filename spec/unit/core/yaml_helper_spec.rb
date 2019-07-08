require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe 'In general' do
    before do
      @good_podfile_lock      = File.open(
        File.expand_path('../fixtures/Podfile.lock', __FILE__))

      @bad_yaml_podfile_lock  = File.open(
        File.expand_path('../fixtures/PodfileWithIncorrectYAML.lock', __FILE__))

      @conflict_podfile_lock  = File.open(
        File.expand_path('../fixtures/PodfileWithMergeConflicts.lock', __FILE__))
    end

    after do
      @good_podfile_lock.close
      @bad_yaml_podfile_lock.close
      @conflict_podfile_lock.close
    end

    describe YAMLHelper do
      it 'converts a string' do
        value = 'Value'
        result = YAMLHelper.convert(value)
        result.should == "Value\n"
      end

      it 'converts a long string without adding line breaks' do
        value = 'a b' * 2000
        result = YAMLHelper.convert(value)
        result.should == "#{value}\n"
      end

      it 'coverts a string that looks like a float' do
        value = '1.2'
        result = YAMLHelper.convert(value)
        result.should == "'1.2'\n"
        YAMLHelper.load_string(result).should == value
      end

      it 'converts weird strings' do
        {
          'true' => "'true'",
          'false' => "'false'",
          'null' => "'null'",
          '-1' => "'-1'",
          '' => "''",
          '!' => '"!"',
          '!ProtoCompiler' => '"!ProtoCompiler"',
          '~' => "'~'",
          'foo:' => '"foo:"',
          'https://github.com/CocoaPods/Core.git' => 'https://github.com/CocoaPods/Core.git',
          'a (from `b`)' => 'a (from `b`)',
          'monkey (< 1.0.9, ~> 1.0.1)' => 'monkey (< 1.0.9, ~> 1.0.1)',
        }.each do |given, expected|
          converted = YAMLHelper.convert(given)
          converted[0..-2].should == expected
          YAMLHelper.load_string("---\n#{converted}").should == given
        end
      end

      it 'converts a symbol' do
        value = :value
        result = YAMLHelper.convert(value)
        result.should == ":value\n"
      end

      it 'converts the true class' do
        result = YAMLHelper.convert(true)
        result.should == "true\n"
      end

      it 'converts the false class' do
        result = YAMLHelper.convert(false)
        result.should == "false\n"
      end

      it 'converts an array' do
        value = %w(Value_1 Value_2)
        result = YAMLHelper.convert(value)
        result.should == "- Value_1\n- Value_2\n"
      end

      it 'converts an array that contains an array' do
        value = [%w(Value_1 Value_2), %w(Value_3 Value_4)]
        result = YAMLHelper.convert(value)
        result.should == "- - Value_1\n  - Value_2\n- - Value_3\n  - Value_4\n"
      end

      it 'converts an hash' do
        value = { 'Key' => 'Value' }
        result = YAMLHelper.convert(value)
        result.should == "Key: Value\n"
      end

      it 'converts an hash which contains an array as one of the values' do
        value = { 'Key' => %w(Value_1 Value_2) }
        result = YAMLHelper.convert(value)
        result.should == <<-EOT.strip_heredoc
        Key:
          - Value_1
          - Value_2
        EOT
      end

      it 'converts an hash which contains an empty array as one of the values' do
        value = { 'Key' => [] }
        result = YAMLHelper.convert(value)
        result.should == <<-YAML.strip_heredoc
          Key:
            []
        YAML
      end

      it 'converts an array with contains an empty hash' do
        value = { 'Key' => [{}] }
        result = YAMLHelper.convert(value)
        result.should == <<-YAML.strip_heredoc
          Key:
            - {}
        YAML
      end

      it 'converts an hash which contains an array as one of the values' do
        value = { 'Key' => { 'Subkey' => %w(Value_1 Value_2) } }
        result = YAMLHelper.convert(value)
        result.should == <<-EOT.strip_heredoc
        Key:
          Subkey:
            - Value_1
            - Value_2
        EOT
      end

      it 'converts a hash with complex keys' do
        value = { 'Key' => {
          "\n\t  \r\t\b\r\n  " => 'spaces galore',
          '!abc' => 'abc',
          '!ABC' => 'ABC',
          '123' => '123',
          "a # 'comment'?" => "a # 'comment'?",
          %q('"' lotsa '"""'''" quotes) => %q('"' lotsa '"""'''" quotes),
        } }
        result = YAMLHelper.convert(value)
        result.should == <<-EOT.strip_heredoc
          Key:
            "\\n\\t  \\r\\t\\b\\r\\n  ": spaces galore
            "!abc": abc
            "!ABC": ABC
            "'\\"' lotsa '\\"\\"\\"'''\\" quotes": "'\\"' lotsa '\\"\\"\\"'''\\" quotes"
            '123': '123'
            "a # 'comment'?": "a # 'comment'?"
        EOT
        YAMLHelper.load_string(result).should == value
      end

      it 'handles nil' do
        value = { 'foo' => nil }
        result = YAMLHelper.convert(value)
        result.should == <<-EOT.strip_heredoc
          foo:
        EOT
        YAMLHelper.load_string(result).should == value
      end

      it 'handles objects of unknown classes' do
        value = Pathname.new('a-path')
        result = YAMLHelper.convert(value)
        result.should == <<-EOT.strip_heredoc
          !ruby/object:Pathname
          path: a-path
        EOT
        YAMLHelper.load_string(result).should == value
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Loading Strings' do
      it 'raises an Informative error when it encounters a merge conflict' do
        should.raise Informative do
          YAMLHelper.load_string(@conflict_podfile_lock.read)
        end.message.should.match /unable to continue due to merge conflicts/
      end

      it 'raises error when encountering a non-merge conflict error' do
        should.raise Exception do
          YAMLHelper.load_string(@bad_yaml_podfile_lock.read)
        end
      end

      it 'should not raise when there is no merge conflict' do
        should.not.raise do
          YAMLHelper.load_string(@good_podfile_lock.read)
        end
      end
    end

    describe 'Loading Files' do
      it 'raises an Informative error when it encounters a merge conflict' do
        should.raise Informative do
          YAMLHelper.load_file(Pathname.new(@conflict_podfile_lock.path))
        end.message.should.match /unable to continue due to merge conflicts/
      end

      it 'raises error when it encounters a non-merge conflict error' do
        should.raise Exception do
          YAMLHelper.load_file(Pathname.new(@bad_yaml_podfile_lock.path))
        end
      end

      it 'should not raise when there is no merge conflict' do
        should.not.raise do
          YAMLHelper.load_file(Pathname.new(@good_podfile_lock.path))
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Private Helpers' do
      describe '#sorted_array_with_hint' do
        it 'sorts an array according to its string representation' do
          values = %w(JSONKit BananaLib)
          result = YAMLHelper.send(:sorted_array, values)
          result.should == %w(BananaLib JSONKit)
        end

        it 'sorts an array containing strings and hashes according to its string representation' do
          values = ['JSONKit', 'BananaLib', { 'c_hash_key' => 'a_value' }]
          result = YAMLHelper.send(:sorted_array, values)
          result.should == ['BananaLib', { 'c_hash_key' => 'a_value' }, 'JSONKit']
        end

        it 'sorts an array with a given hint' do
          values = %w(non-hinted second first)
          hint = %w(first second hinted-missing)
          result = YAMLHelper.send(:sorted_array_with_hint, values, hint)
          result.should == %w(first second non-hinted)
        end

        it 'sorts an array with a given nil hint' do
          values = %w(JSONKit BananaLib)
          hint = nil
          result = YAMLHelper.send(:sorted_array_with_hint, values, hint)
          result.should == %w(BananaLib JSONKit)
        end
      end

      describe '#sorting_string' do
        it 'returns the empty string if a nil value is passed' do
          value = nil
          result = YAMLHelper.send(:sorting_string, value)
          result.should == ''
        end

        it 'sorts strings ignoring case' do
          value = 'String'
          result = YAMLHelper.send(:sorting_string, value)
          result.should == 'string'
        end

        it 'sorts symbols ignoring case' do
          value = :Symbol
          result = YAMLHelper.send(:sorting_string, value)
          result.should == 'symbol'
        end

        it 'sorts arrays using the first element ignoring case' do
          value = %w(String_2 String_1)
          result = YAMLHelper.send(:sorting_string, value)
          result.should == 'string_2'
        end

        it 'sorts a hash using first key in alphabetical order' do
          value = {
            :key_2 => 'a_value',
            :key_1 => 'a_value',
          }
          result = YAMLHelper.send(:sorting_string, value)
          result.should == 'key_1'
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Lockfile generation' do
      it 'converts a complex file' do
        podfile_str = @good_podfile_lock.read
        value = YAMLHelper.load_string(podfile_str)
        sorted_keys = ['PODS', 'DEPENDENCIES', 'SPEC CHECKSUMS', 'COCOAPODS']
        result = YAMLHelper.convert_hash(value, sorted_keys, "\n\n")
        YAMLHelper.load_string(result).should == value
        result.should == podfile_str
      end
    end

    #-------------------------------------------------------------------------#
  end

  #---------------------------------------------------------------------------#
end
