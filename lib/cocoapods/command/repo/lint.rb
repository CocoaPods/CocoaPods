module Pod
  class Command
    class Repo < Command
      class Lint < Repo
        self.summary = 'Validates all specs in a repo.'

        self.description = <<-DESC
          Lints the spec-repo `NAME`. If a directory is provided it is assumed
          to be the root of a repo. Finally, if `NAME` is not provided this
          will lint all the spec-repos known to CocoaPods.
        DESC

        self.arguments = [
          CLAide::Argument.new(%w(NAME DIRECTORY), false),
        ]

        def self.options
          [
            ['--only-errors', 'Lint presents only the errors'],
          ].concat(super)
        end

        def initialize(argv)
          @name = argv.shift_argument
          @only_errors = argv.flag?('only-errors')
          super
        end

        # Run the command
        #
        # @todo Part of this logic needs to be ported to cocoapods-core so web
        #       services can validate the repo.
        #
        # @todo add UI.print and enable print statements again.
        #
        def run
          if @name
            sources = SourcesManager.sources([@name])
          else
            sources = SourcesManager.aggregate.sources
          end

          sources.each do |source|
            SourcesManager.check_version_information(source.repo)
            UI.puts "\nLinting spec repo `#{source.repo.basename}`\n".yellow

            validator = Source::HealthReporter.new(source.repo)
            validator.pre_check do |_name, _version|
              UI.print '.'
            end
            report = validator.analyze
            UI.puts
            UI.puts

            report.pods_by_warning.each do |message, versions_by_name|
              UI.puts "-> #{message}".yellow
              versions_by_name.each { |name, versions| UI.puts "  - #{name} (#{versions * ', '})" }
              UI.puts
            end

            report.pods_by_error.each do |message, versions_by_name|
              UI.puts "-> #{message}".red
              versions_by_name.each { |name, versions| UI.puts "  - #{name} (#{versions * ', '})" }
              UI.puts
            end

            UI.puts "Analyzed #{report.analyzed_paths.count} podspecs files.\n\n"
            if report.pods_by_error.count.zero?
              UI.puts 'All the specs passed validation.'.green << "\n\n"
            else
              raise Informative, "#{report.pods_by_error.count} podspecs failed validation."
            end
          end
        end
      end
    end
  end
end
