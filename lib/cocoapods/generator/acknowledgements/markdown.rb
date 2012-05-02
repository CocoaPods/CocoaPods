module Pod
  module Generator

    class Markdown < Acknowledgements

      def title_from_string(string)
        if string != ""
          "#{string}\n" + '-' * string.length + "\n"
        end
      end
 
      def string_for_pod(pod)
        if (license_text = pod.license_text)
          title_from_string(pod.name) + license_text + "\n"
        end
      end

      def licenses
        licenses_string = "#{title_from_string(header_title)}#{header_text}\n"
        @pods.each do |pod|
          licenses_string += string_for_pod(pod)
        end
        licenses_string += "#{title_from_string(footnote_title)}#{footnote_text}\n"
      end
   end
  end
end
