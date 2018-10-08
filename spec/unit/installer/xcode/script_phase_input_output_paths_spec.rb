require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      describe ScriptPhaseInputOutputPaths do
        describe '#use_xcfilelist?' do
          it 'returns true when the object version is >= 50' do
            object_versions = %w(50 51 149)
            object_versions.each do |object_version|
              project = Xcodeproj::Project.new('path/project.xcodeproj', false, object_version)
              ScriptPhaseInputOutputPaths.use_xcfilelist?(project).should == true
            end
          end

          it 'returns false when the object version is < 50' do
            object_versions = %w(47 49)
            object_versions.each do |object_version|
              project = Xcodeproj::Project.new('path/project.xcodeproj', false, object_version)
              ScriptPhaseInputOutputPaths.use_xcfilelist?(project).should == false
            end
          end
        end

        describe '#update_script_phase_paths' do
          describe '#use_xcfilelist? returns false' do
            before do
              ScriptPhaseInputOutputPaths.expects(:use_xcfilelist? => false)
            end

            it 'sets the paths directly' do
              FileUtils.expects(:rm).with('input.xcfilelist')
              FileUtils.expects(:rm).with('output.xcfilelist')

              input_paths = %w(input1 input2)
              output_paths = %w(output1 output2)
              file_list_directory = Pathname('file_list_directory')
              script_phase = mock('script phase',
                                  :project => mock('project'),
                                  :input_file_list_paths => ['input.xcfilelist'],
                                  :output_file_list_paths => ['output.xcfilelist'],
                                 )

              script_phase.expects(:input_file_list_paths=).with(nil)
              script_phase.expects(:output_file_list_paths=).with(nil)
              script_phase.expects(:input_paths=).with(input_paths)
              script_phase.expects(:output_paths=).with(output_paths)

              ScriptPhaseInputOutputPaths.update_script_phase_paths(script_phase, file_list_directory, :input_paths => input_paths, :output_paths => output_paths)
            end

            it 'sets the paths directly when file list paths are unset' do
              input_paths = %w(input1 input2)
              output_paths = %w(output1 output2)
              file_list_directory = Pathname('file_list_directory')
              script_phase = mock('script phase',
                                  :project => mock('project'),
                                  :input_file_list_paths => nil,
                                  :output_file_list_paths => nil,
                                 )

              script_phase.expects(:input_paths=).with(input_paths)
              script_phase.expects(:output_paths=).with(output_paths)

              ScriptPhaseInputOutputPaths.update_script_phase_paths(script_phase, file_list_directory, :input_paths => input_paths, :output_paths => output_paths)
            end
          end

          describe '#use_xcfilelist? returns true' do
            before do
              ScriptPhaseInputOutputPaths.expects(:use_xcfilelist? => true)
            end

            it 'sets the paths via xcfilelist' do
              input_paths = %w(input1 input2)
              output_paths = %w(output1 output2)
              file_list_directory = Pathname('file_list_directory')
              script_phase = mock('script phase',
                                  :project => mock('project'),
                                  :input_paths => ['input3'],
                                  :output_paths => ['output3'],
                                 )

              PodsProjectGenerator::TargetInstallerHelper.expects(:update_changed_file).
                with(responds_with(:generate, "input1\ninput2"), file_list_directory + 'input_files.xcfilelist')
              PodsProjectGenerator::TargetInstallerHelper.expects(:update_changed_file).
                with(responds_with(:generate, "output1\noutput2"), file_list_directory + 'output_files.xcfilelist')

              script_phase.expects(:input_paths=).with(nil)
              script_phase.expects(:output_paths=).with(nil)
              script_phase.expects(:input_file_list_paths=).with(%W(#{file_list_directory + 'input_files.xcfilelist'}))
              script_phase.expects(:output_file_list_paths=).with(%W(#{file_list_directory + 'output_files.xcfilelist'}))

              ScriptPhaseInputOutputPaths.update_script_phase_paths(script_phase, file_list_directory, :input_paths => input_paths, :output_paths => output_paths)
            end

            it 'sets the paths via xcfilelist when explicit paths are unset' do
              input_paths = %w(input1 input2)
              output_paths = %w(output1 output2)
              file_list_directory = Pathname('file_list_directory')
              script_phase = mock('script phase',
                                  :project => mock('project'),
                                  :input_paths => nil,
                                  :output_paths => nil,
                                 )

              PodsProjectGenerator::TargetInstallerHelper.expects(:update_changed_file).
                with(responds_with(:generate, "input1\ninput2"), file_list_directory + 'input_files.xcfilelist')
              PodsProjectGenerator::TargetInstallerHelper.expects(:update_changed_file).
                with(responds_with(:generate, "output1\noutput2"), file_list_directory + 'output_files.xcfilelist')

              script_phase.expects(:input_file_list_paths=).with(%W(#{file_list_directory + 'input_files.xcfilelist'}))
              script_phase.expects(:output_file_list_paths=).with(%W(#{file_list_directory + 'output_files.xcfilelist'}))

              ScriptPhaseInputOutputPaths.update_script_phase_paths(script_phase, file_list_directory, :input_paths => input_paths, :output_paths => output_paths)
            end
          end
        end
      end
    end
  end
end
