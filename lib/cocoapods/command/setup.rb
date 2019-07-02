require 'fileutils'

module Pod
  class Command
    class Setup < Command
      self.summary = 'Legacy command present for compatibility reasons - deprecated in 1.8.0'

      self.description = <<-DESC
        Legacy command that is present for compatibility reasons.
        The new CDN-based trunk repo does not need any specific setup steps.
      DESC

      def run
        UI.puts '`pod setup` was deprecated in 1.8.0, because new CDN trunk does not need any specific setup steps.'.green
      end
    end
  end
end
