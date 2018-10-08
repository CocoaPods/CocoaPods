module Pod
  class Installer
    class Xcode
      module ScriptPhaseInputOutputPaths
        module_function

        def use_xcfilelist?(project)
          project.object_version.to_i >= 50
        end

        def update_script_phase_paths(script_phase, file_list_directory, input_paths: [], output_paths: [])
          if use_xcfilelist?(script_phase.project)
            script_phase.input_paths &&= nil
            script_phase.output_paths &&= nil

            input_file_list_path = file_list_directory.join('input_files.xcfilelist')
            PodsProjectGenerator::TargetInstallerHelper.update_changed_file(Generator::Constant.new(input_paths.join("\n")), input_file_list_path)
            script_phase.input_file_list_paths = [input_file_list_path.to_s]

            output_file_list_path = file_list_directory.join('output_files.xcfilelist')
            PodsProjectGenerator::TargetInstallerHelper.update_changed_file(Generator::Constant.new(output_paths.join("\n")), output_file_list_path)
            script_phase.output_file_list_paths = [output_file_list_path.to_s]
          else
            if input_file_list_paths = script_phase.input_file_list_paths
              input_file_list_paths.each { |f| FileUtils.rm f }
              script_phase.input_file_list_paths = nil
            end
            if output_file_list_paths = script_phase.output_file_list_paths
              output_file_list_paths.each { |f| FileUtils.rm f }
              script_phase.output_file_list_paths = nil
            end

            script_phase.input_paths = input_paths
            script_phase.output_paths = output_paths
          end
        end
      end
    end
  end
end
