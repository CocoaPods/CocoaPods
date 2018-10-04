module Pod
  class Installer
    class Xcode
      autoload :PodsProjectGenerator, 'cocoapods/installer/xcode/pods_project_generator'
      autoload :ScriptPhaseInputOutputPaths, 'cocoapods/installer/xcode/script_phase_input_output_paths'
      autoload :TargetValidator, 'cocoapods/installer/xcode/target_validator'
    end
  end
end
