module Pod
  module Generator
    class Plist < Acknowledgements
      def self.path_from_basepath(path)
        Pathname.new(path.dirname + "#{path.basename}.plist")
      end

      def save_as(path)
        Xcodeproj.write_plist(plist, path)
      end

      def plist
        {
          :Title => plist_title,
          :StringsTable => plist_title,
          :PreferenceSpecifiers => licenses,
        }
      end

      def plist_title
        'Acknowledgements'
      end

      def licenses
        licences_array = [header_hash]
        specs.each do |spec|
          if (hash = hash_for_spec(spec))
            licences_array << hash
          end
        end
        licences_array << footnote_hash
      end

      def hash_for_spec(spec)
        if (license = license_text(spec))
          {
            :Type => 'PSGroupSpecifier',
            :Title => sanitize_encoding(spec.name),
            :FooterText => sanitize_encoding(license),
          }
        end
      end

      def header_hash
        {
          :Type => 'PSGroupSpecifier',
          :Title => sanitize_encoding(header_title),
          :FooterText => sanitize_encoding(header_text),
        }
      end

      def footnote_hash
        {
          :Type => 'PSGroupSpecifier',
          :Title => sanitize_encoding(footnote_title),
          :FooterText => sanitize_encoding(footnote_text),
        }
      end

      #-----------------------------------------------------------------------#

      private

      # !@group Private methods

      # Returns the sanitized text with UTF-8 eliminating invalid characters if
      # Ruby version >=1.9 else will return the text.
      #
      # @param  [String] text
      #         the text we want to sanitize.
      #
      # @return [String] The sanitized text if Ruby >=1.9 else text.
      #
      def sanitize_encoding(text)
        if RUBY_VERSION >= '1.9'
          text.encode('UTF-8', :invalid => :replace, :undef => :replace, :replace => '')
        else
          text
        end
      end

      #-----------------------------------------------------------------------#
    end
  end
end
