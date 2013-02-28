# Restores the config to the default state before each requirement

module Bacon
  class Context
    old_run_requirement = instance_method(:run_requirement)

    define_method(:run_requirement) do |description, spec|
      ::Pod::Config.instance = nil
      ::Pod::Config.instance.tap do |c|
        c.verbose           =  false
        c.silent            =  true
        c.repos_dir         =  fixture('spec-repos')
        c.installation_root =  SpecHelper.temporary_directory
        c.install_docs      =  false
        c.generate_docs     =  false
        c.skip_repo_update  =  true
      end

      ::Pod::UI.output = ''
      # The following prevents a nasty behaviour where the increments are not
      # balanced when testing informative which might lead to sections not
      # being printed to the output as they are too nested.
      ::Pod::UI.indentation_level = 0
      ::Pod::UI.title_level = 0

      SpecHelper.temporary_directory.rmtree if SpecHelper.temporary_directory.exist?
      SpecHelper.temporary_directory.mkpath

      old_run_requirement.bind(self).call(description, spec)
    end
  end
end

