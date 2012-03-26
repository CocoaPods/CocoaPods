module Pod
  class Command
    module DisplayPods

      def display_pod_list(array, stats = false)
        array.each do |set|
          puts_pod(set, stats)
        end
      end

      def puts_pod(set, stats = false)
        puts "\e[32m--> #{set.name} (#{set.versions.reverse.join(", ")})\e[0m"
        puts_wrapped_text(set.specification.summary)

        spec = set.specification.part_of_other_pod? ? set.specification.part_of_specification : set.specification

        source = spec.source.reject {|k,_| k == :commit || k == :tag }.values.first
        puts_detail('Homepage', spec.homepage)
        puts_detail('Source', source)
        puts_github_info(source) if stats
        puts
      end

      # adapted from http://blog.macromates.com/2006/wrapping-text-with-regular-expressions/
      def puts_wrapped_text(txt, col = 80, indentation = 4)
        indent = ' ' * indentation
        puts txt.strip.gsub(/(.{1,#{col}})( +|$)\n?|(.{#{col}})/, indent + "\\1\\3\n")
      end

      def puts_detail(title,string)
        return if !string
        # 8 is the length of homepage which might be displayed alone
        number_of_spaces = ((8 - title.length) > 0) ? (8 - title.length) : 0
        spaces = ' ' * number_of_spaces
        puts "    - #{title}: #{spaces + string}"
      end

      def puts_github_info(url)
        original_url, username, reponame = *(url.match(/[:\/]([\w\-]+)\/([\w\-]+)\.git/).to_a)

        if original_url
          repo_info = `curl -s -m 2 http://github.com/api/v2/json/repos/show/#{username}/#{reponame}`
          watchers = repo_info.match(/\"watchers\"\W*:\W*([0-9]+)/).to_a[1]
          forks = repo_info.match(/\"forks\"\W*:\W*([0-9]+)/).to_a[1]
          puts_detail('Watchers', watchers)
          puts_detail('Forks', forks)
        end
      end
    end
  end
end
