module Pod
  module Generator

    class Plist < Acknowledgements
      require "xcodeproj/xcodeproj_ext"

      def save_as(path)
        if (path.extname != ".plist")
          path = Pathname.new(path.dirname + "#{path.basename.to_s}.plist")
        end
        Xcodeproj.write_plist(plist, path)
      end

      def plist
        {
          :Title => "Acknowledgements",
          :StringsTable => "Acknowledgements",
          :PreferenceSpecifiers => licenses
        }
      end
  
      def licenses
        licences_array = [header_hash]
        @pods.each do |pod|
          if (hash = hash_for_pod(pod))
            licences_array << hash
          end
        end
        licences_array << footnote_hash
      end

      def hash_for_pod(pod)
        if (license = pod.license_text)
          {
            :Type => "PSGroupSpecifier",
            :Title => pod.name,
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
