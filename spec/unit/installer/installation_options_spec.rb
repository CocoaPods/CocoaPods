require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::InstallationOptions do
    describe 'registered options' do
      {
        'clean' => true,
        'deduplicate_targets' => true,
        'deterministic_uuids' => true,
        'integrate_targets' => true,
        'lock_pod_sources' => true,
        'share_schemes_for_development_pods' => false,
        'preserve_pod_file_structure' => false,
      }.each do |option, default|
        it "includes `#{option}` defaulting to `#{default}`" do
          Installer::InstallationOptions.defaults.fetch(option).should == default
          Installer::InstallationOptions.new.send(option).should == default
        end
      end
    end

    describe '.from_podfile' do
      it 'raises for a non-cocoapods install' do
        podfile = Podfile.new { install! 'foo', :key => 'value' }
        exception = should.raise(Informative) { Installer::InstallationOptions.from_podfile(podfile) }
        exception.message.should.include 'Currently need to specify a `cocoapods` install, you chose `foo`.'
      end

      it 'parses the name in a case-insensitive manner' do
        podfile = Podfile.new { install! 'CoCoApOdS' }
        should.not.raise(Informative) { Installer::InstallationOptions.from_podfile(podfile) }
      end

      it 'uses the installation method options to create the options' do
        options = { :integrate_targets => false }
        podfile = Podfile.new { install! 'cocoapods', options }
        installation_options = Installer::InstallationOptions.from_podfile(podfile)
        installation_options.should == Installer::InstallationOptions.new(options)
      end
    end

    describe '#initialize' do
      it 'uses all defaults when no options are specified' do
        Installer::InstallationOptions.new.to_h(:include_defaults => false).should.be.empty
      end

      it 'sets the values as specified in the options' do
        installation_options = Installer::InstallationOptions.new(:deterministic_uuids => false)
        installation_options.deterministic_uuids.should.be.false
      end

      it 'raises when unknown keys are encountered' do
        exception = should.raise(Informative) { Installer::InstallationOptions.new(:a => 'a', :b => 'b', :c => 'c') }
        exception.message.should.include 'Unknown installation options: a, b, and c.'
      end
    end

    describe '#to_h' do
      it 'includes all options by default' do
        installation_options = Installer::InstallationOptions.new(:deterministic_uuids => false)
        installation_options.to_h.should == {
          'clean' => true,
          'deduplicate_targets' => true,
          'deterministic_uuids' => false,
          'integrate_targets' => true,
          'lock_pod_sources' => true,
          'warn_for_multiple_pod_sources' => true,
          'warn_for_unused_master_specs_repo' => true,
          'share_schemes_for_development_pods' => false,
          'disable_input_output_paths' => false,
          'preserve_pod_file_structure' => false,
          'generate_multiple_pod_projects' => false,
          'incremental_installation' => false,
          'skip_pods_project_generation' => false,
        }
      end

      it 'removes default values when specified' do
        installation_options = Installer::InstallationOptions.new(:deterministic_uuids => false)
        installation_options.to_h(:include_defaults => false).should == {
          'deterministic_uuids' => false,
        }
      end
    end
  end
end
