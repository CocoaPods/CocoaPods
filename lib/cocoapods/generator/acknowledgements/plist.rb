module Pod
  module Generator

    class Plist < Acknowledgements
      require "xcodeproj/xcodeproj_ext"

      def self.path_from_basepath(path)
        Pathname.new(path.dirname + "#{path.basename.to_s}.plist")
      end

      def save_as(path)
        Xcodeproj.write_plist(plist, path)
      end

      def plist
        {
          :Title => plist_title,
          :StringsTable => plist_title,
          :PreferenceSpecifiers => licenses
        }
      end

      def plist_title
        "Acknowledgements"
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
            :Type => "PSGroupSpecifier",
            :Title => spec.name,
            :FooterText => license
          }
        end
      end

      def header_hash
        {
          :Type => "PSGroupSpecifier",
          :Title => header_title,
          :FooterText => header_text
        }
      end

      def footnote_hash
        {
          :Type => "PSGroupSpecifier",
          :Title => footnote_title,
          :FooterText => footnote_text
        }
      end
    end
  end
end
