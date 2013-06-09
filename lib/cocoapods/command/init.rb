module Pod
  class Command
    class Init < Command
      self.summary = 'Create a Podfile'

      self.description = <<-DESC
        Creates a Podfile for the current directory if none currently exists.
      DESC

      def run
        (Pathname.pwd + "Podfile").open('w') { |f| f << '' }
      end
    end
  end
end
