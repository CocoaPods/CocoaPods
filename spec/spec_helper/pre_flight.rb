# Restores the config to the default state before each requirement

module Bacon
  class Context
    old_run_requirement = instance_method(:run_requirement)

    define_method(:run_requirement) do |description, spec|

      environment.stubs(:repos_dir).returns(fixture('spec-repos'))
      environment.stubs(:installation_root).returns(SpecHelper.temporary_directory)
      environment.stubs(:home_dir).returns(SpecHelper.temporary_directory)

      config.stubs(:silent).returns(true)
      config.stubs('skip_repo_update').returns(true)

      ::Pod::UI.output = ''
      # The following prevents a nasty behaviour where the increments are not
      # balanced when testing informative which might lead to sections not
      # being printed to the output as they are too nested.
      ::Pod::UI.indentation_level = 0
      ::Pod::UI.title_level = 0

      SpecHelper.temporary_directory.rmtree if SpecHelper.temporary_directory.exist?
      SpecHelper.temporary_directory.mkpath

      # TODO
      ::Pod::SourcesManager.stubs(:search_index_path).returns(temporary_directory + 'search_index.yaml')

      old_run_requirement.bind(self).call(description, spec)
    end
  end
end

