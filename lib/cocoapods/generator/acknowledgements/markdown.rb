module Pod
  module Generator

    class Markdown < Acknowledgements

      def save_as(path)
        if (path.extname != ".markdown")
          path = Pathname.new(path.dirname + "#{path.basename.to_s}.markdown")
        end
        file = File.new(path, "w")
        file.write(licenses)
        file.close
      end

      def title_from_string(string, level)
        if !string.empty?
          "#" * level << " #{string}"
        end
      end

      def string_for_pod(pod)
        if (license_text = pod.license_text)
          "\n" << title_from_string(pod.name, 2) << "\n\n" << license_text << "\n"
        end
      end

      def licenses
        licenses_string = "#{title_from_string(header_title, 1)}\n#{header_text}\n"
        @pods.each do |pod|
          if (license = string_for_pod(pod))
            license = license.force_encoding("UTF-8") if license.respond_to?(:force_encoding) 
            licenses_string += license
          end
        end
        licenses_string += "#{title_from_string(footnote_title, 2)}#{footnote_text}\n"
      end
    end
  end
end
