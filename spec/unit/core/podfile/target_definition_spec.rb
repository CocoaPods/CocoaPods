require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Podfile::TargetDefinition do
    before do
      @podfile = Podfile.new
      @root = Podfile::TargetDefinition.new('Pods', @podfile)
      @parent = Podfile::TargetDefinition.new('MyApp', @root)
      @child = Podfile::TargetDefinition.new('MyAppTests', @parent)
      @child.inheritance = :search_paths
      @abstract = Podfile::TargetDefinition.new('MyAbstractTarget', @root)
      @abstract.abstract = true
      @parent.set_platform(:ios, '6.0')
    end

    #-------------------------------------------------------------------------#

    describe 'In general' do
      it 'returns its name' do
        @parent.name.should == 'MyApp'
      end

      it 'returns the parent' do
        @root.parent.should == @podfile
        @parent.parent.should == @root
        @child.parent.should == @parent
      end

      #--------------------------------------#

      it 'returns the children' do
        @parent.children.should == [@child]
        @child.children.should == []
      end

      it 'returns the recursive children' do
        @grand_child = Podfile::TargetDefinition.new('MyAppTests', @child)
        @parent.recursive_children.should == [@child, @grand_child]
        @child.recursive_children.should == [@grand_child]
        @grand_child.recursive_children.should == []
      end

      it 'returns whether it is root' do
        @root.should.be.root
        @parent.should.not.be.root
        @child.should.not.be.root
      end

      it 'returns the root target definition' do
        @root.root.should == @root
        @parent.root.should == @root
        @child.root.should == @root
      end

      it 'returns the podfile that specifies it' do
        @parent.podfile.class.should == Podfile
        @child.podfile.class.should == Podfile
      end

      it 'returns dependencies' do
        @root.store_pod('AFNetworking')
        @parent.store_pod('BlocksKit')
        @child.store_pod('OCMockito')
        @child.inheritance = :complete
        @parent.dependencies.map(&:name).should == %w(BlocksKit AFNetworking)
        @child.dependencies.map(&:name).should == %w(OCMockito BlocksKit AFNetworking)
      end

      it "doesn't inherit dependencies if it is exclusive" do
        @parent.store_pod('BlocksKit')
        @child.store_pod('OCMockito')
        @child.inheritance = :none
        @child.dependencies.map(&:name).should == %w(OCMockito)
      end

      it 'returns the targets to inherit search paths from' do
        @child.inheritance = :search_paths
        @child.targets_to_inherit_search_paths.should == [@parent]

        grandchild = Podfile::TargetDefinition.new('Grandchild', @child)
        grandchild.targets_to_inherit_search_paths.should == [@parent]
        grandchild.inheritance = :search_paths
        grandchild.targets_to_inherit_search_paths.should == [@parent, @child]
        @child.inheritance = :complete
        grandchild.targets_to_inherit_search_paths.should == [@child]
        @child.inheritance = :none
        grandchild.targets_to_inherit_search_paths.should == [@child]
      end

      it 'returns the non inherited dependencies' do
        @parent.store_pod('BlocksKit')
        @child.store_pod('OCMockito')
        @parent.non_inherited_dependencies.map(&:name).should == %w(BlocksKit)
        @child.non_inherited_dependencies.map(&:name).should == %w(OCMockito)
      end

      it 'returns whether it is empty' do
        @parent.store_pod('BlocksKit')
        @parent.should.not.be.empty
        @child.should.be.empty
      end

      it 'returns its label' do
        @parent.label.should == 'Pods-MyApp'
      end

      it 'returns `Pods` as the label if its name is default' do
        target_def = Podfile::TargetDefinition.new('Pods', @podfile)
        target_def.label.should == 'Pods'
      end

      it 'includes the name of the parent in the label if any' do
        @child.inheritance = :complete
        @child.label.should == 'Pods-MyApp-MyAppTests'
      end

      it "doesn't include the name of the parent in the label if it is exclusive" do
        @child.inheritance = :none
        @child.label.should == 'Pods-MyAppTests'
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Attributes accessors' do
      it 'is not abstract by default' do
        @child.should.not.be.abstract
      end

      it 'allows to set whether it is abstract' do
        @child.abstract = true
        @child.should.be.abstract
      end

      #--------------------------------------#

      it 'has complete inheritance by default' do
        Podfile::TargetDefinition.new('App', nil).inheritance.should == 'complete'
      end

      it 'allows setting the inheritance' do
        @child.inheritance = :complete
        @child.inheritance.should == 'complete'
        @child.inheritance = :none
        @child.inheritance.should == 'none'
        @child.inheritance = :search_paths
        @child.inheritance.should == 'search_paths'
      end

      it 'raises when setting an unknown inheritance mode' do
        exception = should.raise(Informative) { @child.inheritance = :unknown }
        exception.message.should == 'Unrecognized inheritance option `unknown` specified for target `MyAppTests`.'
      end

      it 'raises when setting an inheritance mode on a root target definition' do
        exception = should.raise(Informative) { @root.inheritance = :none }
        exception.message.should == 'Cannot set inheritance for the root target definition.'
      end

      it 'raises when setting an inheritance mode on a abstract target definition' do
        exception = should.raise(Informative) { @abstract.inheritance = :none }
        exception.message.should == 'Cannot set inheritance for abstract target definition.'
      end

      #--------------------------------------#

      it 'is exclusive by default by the default if the platform of the parent match' do
        @child.should.be.exclusive
      end

      it "is exclusive by the default if the platform of the parent doesn't match" do
        @parent.set_platform(:osx, '10.6')
        @child.set_platform(:ios, '6.0')
        @child.should.be.exclusive
      end

      it 'allows to set whether it is exclusive' do
        @child.inheritance = :complete
        @child.should.not.be.exclusive
        @child.inheritance = :none
        @child.should.be.exclusive
        @child.inheritance = :search_paths
        @child.should.be.exclusive
      end

      #--------------------------------------#

      it "doesn't specifies any user project by default" do
        @parent.user_project_path.should.be.nil
      end

      it 'allows to set the path of the user project' do
        @parent.user_project_path = 'some/path/project.xcodeproj'
        @parent.user_project_path.should == 'some/path/project.xcodeproj'
      end

      it 'appends the extension to a specified user project if needed' do
        @parent.user_project_path = 'some/path/project'
        @parent.user_project_path.should == 'some/path/project.xcodeproj'
      end

      it 'inherits the path of the user project from the parent' do
        @parent.user_project_path = 'some/path/project.xcodeproj'
        @child.user_project_path.should == 'some/path/project.xcodeproj'
      end

      #--------------------------------------#

      it "doesn't specifies any project build configurations default" do
        @parent.build_configurations.should.be.nil
      end

      it 'allows to set the project build configurations' do
        @parent.build_configurations = { 'Debug' => :debug, 'Release' => :release }
        @parent.build_configurations.should == { 'Debug' => :debug, 'Release' => :release }
      end

      it 'inherits the project build configurations from the parent' do
        @parent.build_configurations = { 'Debug' => :debug, 'Release' => :release }
        @child.build_configurations.should == { 'Debug' => :debug, 'Release' => :release }
      end

      #--------------------------------------#

      it "doesn't add extra subspec dependencies by default" do
        @parent.store_pod('RestKit')
        @parent.dependencies.map(&:name).should == %w(RestKit)
      end

      it 'allows depending on subspecs' do
        @parent.store_pod('RestKit', :subspecs => %w(Networking))
        @parent.dependencies.map(&:name).sort.should == %w(RestKit/Networking)
      end

      it 'allows depending on testspecs' do
        @parent.store_pod('RestKit', :testspecs => %w(Tests))
        @parent.dependencies.map(&:name).sort.should == %w(RestKit RestKit/Tests)
      end

      it 'allows depending on appspecs' do
        @parent.store_pod('RestKit', :appspecs => %w(App))
        @parent.dependencies.map(&:name).sort.should == %w(RestKit RestKit/App)
      end

      it 'allows depending on both subspecs and testspecs' do
        @parent.store_pod('RestKit', :subspecs => %w(Networking))
        @parent.store_pod('RestKit', :testspecs => %w(Tests))
        @parent.dependencies.map(&:name).sort.should == %w(RestKit RestKit/Networking RestKit/Tests)
      end

      it 'allows depending on both subspecs and appspecs' do
        @parent.store_pod('RestKit', :subspecs => %w(Networking))
        @parent.store_pod('RestKit', :appspecs => %w(App))
        @parent.dependencies.map(&:name).sort.should == %w(RestKit RestKit/App RestKit/Networking)
      end

      it 'allows depending on subspecs, testspecs, and appspecs' do
        @parent.store_pod('RestKit', :subspecs => %w(Networking))
        @parent.store_pod('RestKit', :testspecs => %w(Tests))
        @parent.store_pod('RestKit', :appspecs => %w(App))
        @parent.dependencies.map(&:name).sort.should == %w(RestKit RestKit RestKit/App RestKit/Networking RestKit/Tests)
      end

      it 'allows depending on both subspecs and testspecs in chaining' do
        @parent.store_pod('RestKit', :subspecs => %w(Networking), :testspecs => %w(Tests))
        @parent.dependencies.map(&:name).sort.should == %w(RestKit/Networking RestKit/Tests)
      end

      it 'allows depending on both subspecs and appspecs in chaining' do
        @parent.store_pod('RestKit', :subspecs => %w(Networking), :appspecs => %w(App))
        @parent.dependencies.map(&:name).sort.should == %w(RestKit/App RestKit/Networking)
      end

      it 'allows depending on subspecs, testspecs, and appspecs in chaining' do
        @parent.store_pod('RestKit', :subspecs => %w(Networking), :testspecs => %w(Tests), :appspecs => %w(App))
        @parent.dependencies.map(&:name).sort.should == %w(RestKit/App RestKit/Networking RestKit/Tests)
      end

      #--------------------------------------#

      it "doesn't inhibit warnings per pod by default" do
        @parent.store_pod('ObjectiveSugar')
        @parent.should.not.inhibits_warnings_for_pod?('ObjectiveSugar')
      end

      it 'inhibits warnings per pod if passed to store_pod' do
        @parent.store_pod('Objective-Record', :head, :inhibit_warnings => true)
        @parent.should.inhibits_warnings_for_pod?('Objective-Record')

        @parent.store_pod('RestKit/Networking', :head, :inhibit_warnings => true)
        @parent.should.inhibits_warnings_for_pod?('RestKit')
      end

      it 'does not inhibit warnings per pod if the option is false' do
        @parent.inhibit_all_warnings = true
        @parent.store_pod('ASIHTTPRequest', :inhibit_warnings => false)
        @parent.should.not.inhibits_warnings_for_pod?('ASIHTTPRequest')
      end

      it 'must delete the hash if it was empty. otherwise breaks Dependency' do
        reqs = [{ :inhibit_warnings => true }]
        @parent.send(:parse_inhibit_warnings, 'Objective-Record', reqs)
        reqs.should.be.empty
      end

      it 'returns if it should inhibit all warnings' do
        @parent.inhibit_all_warnings = true
        @parent.should.inhibits_warnings_for_pod?('ObjectiveSugar')
      end

      it 'inherits the option to inhibit all warnings' do
        @parent.inhibit_all_warnings = true
        @child.store_pod('ASIHTTPRequest')
        @child.should.inhibits_warnings_for_pod?('ASIHTTPRequest')
      end

      it 'inherits the option to inhibit warnings per pod' do
        @parent.store_pod('Objective-Record', :inhibit_warnings => true)
        @child.should.inhibits_warnings_for_pod?('Objective-Record')
      end

      it 'inherits the false option to inhibit warnings per pod' do
        @parent.inhibit_all_warnings = true
        @child.store_pod('ASIHTTPRequest', :inhibit_warnings => false)
        @child.should.not.inhibits_warnings_for_pod?('ASIHTTPRequest')
      end

      it 'overriding inhibition per pod in child should not affect parent' do
        @parent.store_pod('ASIHTTPRequest', :inhibit_warnings => true)
        @child.store_pod('ASIHTTPRequest', :inhibit_warnings => false)
        @child.should.not.inhibits_warnings_for_pod?('ASIHTTPRequest')
        @parent.should.inhibits_warnings_for_pod?('ASIHTTPRequest')
      end

      #--------------------------------------#

      it "doesn't use modular headers per pod by default" do
        @parent.store_pod('ObjectiveSugar')
        @parent.should.not.build_pod_as_module?('ObjectiveSugar')
      end

      it 'uses modular headers per pod if passed to store_pod' do
        @parent.store_pod('Objective-Record', :head, :modular_headers => true)
        @parent.should.build_pod_as_module?('Objective-Record')

        @parent.store_pod('RestKit/Networking', :head, :modular_headers => true)
        @parent.should.build_pod_as_module?('RestKit')
      end

      it 'does not use modular headers per pod if the option is false' do
        @parent.use_modular_headers_for_all_pods = true
        @parent.store_pod('ASIHTTPRequest', :modular_headers => false)
        @parent.should.not.build_pod_as_module?('ASIHTTPRequest')
      end

      it 'deletes the hash if empty' do
        reqs = [{ :modular_headers => true }]
        @parent.send(:parse_modular_headers, 'Objective-Record', reqs)
        reqs.should.be.empty
      end

      it 'returns if it should use modular headers for all pods' do
        @parent.use_modular_headers_for_all_pods = true
        @parent.should.build_pod_as_module?('ObjectiveSugar')
      end

      it 'inherits the option to use modular headers for all pods' do
        @parent.use_modular_headers_for_all_pods = true
        @child.store_pod('ASIHTTPRequest')
        @child.should.build_pod_as_module?('ASIHTTPRequest')
      end

      it 'inherits the option to use modular headers per pod' do
        @parent.store_pod('Objective-Record', :modular_headers => true)
        @child.should.build_pod_as_module?('Objective-Record')
      end

      it 'inherits the false option to use modular headers per pod' do
        @parent.use_modular_headers_for_all_pods = true
        @child.store_pod('ASIHTTPRequest', :modular_headers => false)
        @child.should.not.build_pod_as_module?('ASIHTTPRequest')
      end

      it 'overriding modular headers per pod in child should not affect parent' do
        @parent.store_pod('ASIHTTPRequest', :modular_headers => true)
        @child.store_pod('ASIHTTPRequest', :modular_headers => false)
        @child.should.not.build_pod_as_module?('ASIHTTPRequest')
        @parent.should.build_pod_as_module?('ASIHTTPRequest')
      end

      #--------------------------------------#

      it 'stores the project name for a given pod' do
        @parent.store_pod('ASIHTTPRequest', :project_name => 'SomeProject')
        @parent.project_name_for_pod('ASIHTTPRequest').should == 'SomeProject'
        @parent.project_name_for_pod('UnknownPod').should.be.nil
      end

      it 'inherits the project name option to use for a pod' do
        @parent.store_pod('ASIHTTPRequest', :project_name => 'SomeProject')
        @child.project_name_for_pod('ASIHTTPRequest').should == 'SomeProject'
      end

      it 'honors the project name directly set from the target definition before delegating to parent' do
        @parent.store_pod('ASIHTTPRequest', :project_name => 'SomeProject')
        @child.store_pod('ASIHTTPRequest', :project_name => 'SomeOtherProject')
        @child.project_name_for_pod('ASIHTTPRequest').should == 'SomeOtherProject'
      end

      #--------------------------------------#

      it 'returns if it should use frameworks' do
        @parent.use_frameworks!
        @parent.should.uses_frameworks?
      end

      it 'inherits the option to use frameworks' do
        @parent.use_frameworks!
        @child.should.uses_frameworks?
      end

      it 'allows children to opt-out of using frameworks' do
        @parent.use_frameworks!
        @child.use_frameworks!(false)
        @child.should.not.uses_frameworks?
        # make sure that the value is not accidentally overwritten on access
        @child.should.not.uses_frameworks?
      end

      #--------------------------------------#

      it 'raises if script phase is missing required key' do
        e = lambda { @parent.store_script_phase(:name => 'PhaseName') }.should.raise Podfile::StandardError
        e.message.should == 'Missing required shell script phase options `script`'
      end

      it 'raises if script phase includes an unrecognized key' do
        e = lambda { @parent.store_script_phase(:name => 'PhaseName', :unknown => 'Unknown') }.should.raise Podfile::StandardError
        e.message.should == 'Unrecognized options `[:unknown]` in shell script `PhaseName` within `MyApp` target. ' \
          'Available options are `[:name, :script, :shell_path, :input_files, :output_files, :input_file_lists, ' \
            ':output_file_lists, :show_env_vars_in_log, :execution_position]`.'
      end

      it 'raises if script phase includes an invalid execution position key' do
        e = lambda { @parent.store_script_phase(:name => 'PhaseName', :script => 'echo "Hello World"', :execution_position => :unknown) }.should.raise Podfile::StandardError
        e.message.should == 'Invalid execution position value `unknown` in shell script `PhaseName` within `MyApp` target. ' \
          'Available options are `[:before_compile, :after_compile, :any]`.'
      end

      it 'raises if the same script phase name already exists' do
        e = lambda do
          @parent.store_script_phase(:name => 'PhaseName', :script => 'echo "Hello World"')
          @parent.store_script_phase(:name => 'PhaseName', :script => 'echo "Hello World"')
        end.should.raise Podfile::StandardError
        e.message.should == 'Script phase with name `PhaseName` name already present for target `MyApp`.'
      end

      it 'stores a script phase if requirements are provided' do
        @parent.store_script_phase(:name => 'PhaseName', :script => 'echo "Hello World"')
        @parent.script_phases.should == [
          { :name => 'PhaseName', :script => 'echo "Hello World"', :execution_position => :any },
        ]
      end

      it 'stores a script phase with requirements and optional keys' do
        @parent.store_script_phase(:name => 'PhaseName', :script => 'echo "Hello World"', :shell_path => '/usr/bin/ruby')
        @parent.script_phases.should == [
          { :name => 'PhaseName', :script => 'echo "Hello World"', :shell_path => '/usr/bin/ruby', :execution_position => :any },
        ]
      end

      it 'stores a script phase with a specified execution position value' do
        @parent.store_script_phase(:name => 'PhaseName', :script => 'echo "Hello World"', :shell_path => '/usr/bin/ruby', :execution_position => :before_compile)
        @parent.script_phases.should == [
          { :name => 'PhaseName', :script => 'echo "Hello World"', :shell_path => '/usr/bin/ruby', :execution_position => :before_compile },
        ]
      end

      #--------------------------------------#

      it 'whitelists pods by default' do
        @parent.store_pod('ObjectiveSugar')
        @parent.should.pod_whitelisted_for_configuration?('ObjectiveSugar', 'Release')
        @child.should.pod_whitelisted_for_configuration?('ObjectiveSugar', 'Release')
      end

      it 'does not enable pods for un-whitelisted configurations if it is whitelisted for another' do
        @parent.store_pod('ObjectiveSugar')
        @parent.whitelist_pod_for_configuration('ObjectiveSugar', 'Release')
        @parent.should.not.pod_whitelisted_for_configuration?('ObjectiveSugar', 'Debug')
        @child.should.not.pod_whitelisted_for_configuration?('ObjectiveSugar', 'Debug')
      end

      it 'enables pods for configurations they are whitelisted for' do
        @parent.store_pod('ObjectiveSugar', :configuration => 'Release')
        @parent.should.pod_whitelisted_for_configuration?('ObjectiveSugar', 'Release')
        @parent.should.not.pod_whitelisted_for_configuration?('ObjectiveSugar', 'Debug')
        @child.should.pod_whitelisted_for_configuration?('ObjectiveSugar', 'Release')
        @child.should.not.pod_whitelisted_for_configuration?('ObjectiveSugar', 'Debug')
        @parent.store_pod('AFNetworking', :configurations => ['Debug'])
        @parent.should.pod_whitelisted_for_configuration?('AFNetworking', 'Debug')
        @parent.should.not.pod_whitelisted_for_configuration?('AFNetworking', 'Release')
        @child.should.pod_whitelisted_for_configuration?('AFNetworking', 'Debug')
        @child.should.not.pod_whitelisted_for_configuration?('AFNetworking', 'Release')
      end

      it 'coerces configuration names to strings' do
        @parent.store_pod('ObjectiveSugar', :configuration => :Release)
        @parent.should.pod_whitelisted_for_configuration?('ObjectiveSugar', 'Release')
        @parent.should.not.pod_whitelisted_for_configuration?('ObjectiveSugar', 'Debug')
      end

      it 'compares build configurations case-insensitively' do
        @parent.store_pod('ObjectiveSugar', :configuration => :Release)
        @parent.should.pod_whitelisted_for_configuration?('ObjectiveSugar', 'Release')
        @parent.should.pod_whitelisted_for_configuration?('objectivesugar', 'Release')
      end

      it 'returns a unique list of all whitelisted configurations' do
        @root.all_whitelisted_configurations.should == []
        @root.whitelist_pod_for_configuration('ObjectiveSugar', 'Release')
        @root.whitelist_pod_for_configuration('AFNetworking', 'Release')
        @root.all_whitelisted_configurations.should == ['Release']
        @child.all_whitelisted_configurations.should == ['Release']
        @root.whitelist_pod_for_configuration('Objective-Record', 'Debug')
        @root.all_whitelisted_configurations.sort.should == %w(Debug Release)
        @child.all_whitelisted_configurations.sort.should == %w(Debug Release)
      end

      it 'whitelists pod configurations with testspecs' do
        @parent.build_configurations = { 'Debug' => :debug, 'Release' => :release }
        @parent.store_pod('RestKit', :testspecs => %w(Tests), :configuration => 'Debug')
        @parent.should.pod_whitelisted_for_configuration?('RestKit', 'Debug')
        @parent.should.pod_whitelisted_for_configuration?('RestKit/Tests', 'Debug')
        @parent.should.not.pod_whitelisted_for_configuration?('RestKit', 'Release')
        @parent.should.not.pod_whitelisted_for_configuration?('RestKit/Tests', 'Release')
      end

      it 'whitelists pod configurations with appspecs' do
        @parent.build_configurations = { 'Debug' => :debug, 'Release' => :release }
        @parent.store_pod('RestKit', :appspecs => %w(App), :configuration => 'Debug')
        @parent.should.pod_whitelisted_for_configuration?('RestKit', 'Debug')
        @parent.should.pod_whitelisted_for_configuration?('RestKit/App', 'Debug')
        @parent.should.not.pod_whitelisted_for_configuration?('RestKit', 'Release')
        @parent.should.not.pod_whitelisted_for_configuration?('RestKit/App', 'Release')
      end

      it 'whitelists pod configurations with appspecs and testspecs' do
        @parent.build_configurations = { 'Debug' => :debug, 'Release' => :release }
        @parent.store_pod('RestKit', :testspecs => %w(Tests), :configuration => 'Debug')
        @parent.store_pod('RestKit', :appspecs => %w(App), :configuration => 'Debug')
        @parent.should.pod_whitelisted_for_configuration?('RestKit', 'Debug')
        @parent.should.pod_whitelisted_for_configuration?('RestKit/App', 'Debug')
        @parent.should.pod_whitelisted_for_configuration?('RestKit/Tests', 'Debug')
        @parent.should.not.pod_whitelisted_for_configuration?('RestKit', 'Release')
        @parent.should.not.pod_whitelisted_for_configuration?('RestKit/App', 'Release')
        @parent.should.not.pod_whitelisted_for_configuration?('RestKit/Tests', 'Release')
      end

      #--------------------------------------#

      it 'returns its platform' do
        @parent.platform.should == Pod::Platform.new(:ios, '6.0')
      end

      it 'inherits the platform form the parent' do
        @parent.platform.should == Pod::Platform.new(:ios, '6.0')
      end

      it 'provides a default deployment target if not specified' do
        @parent.set_platform(:ios)
        @parent.platform.should == Pod::Platform.new(:ios, '4.3')

        @parent.set_platform(:osx)
        @parent.platform.should == Pod::Platform.new(:osx, '10.6')
      end

      it 'raises if the specified platform is unsupported' do
        e = lambda { @parent.set_platform(:win) }.should.raise Podfile::StandardError
        e.message.should.match /Unsupported platform/
      end

      #--------------------------------------#

      it 'returns nil for swift_version by default' do
        @parent.swift_version.should.nil?
      end

      it 'allows you to set the swift_version' do
        @parent.swift_version = '2.3'
        @parent.swift_version.should == '2.3'
      end

      it 'stores a single swift version requirement' do
        @parent.store_swift_version_requirements('3.0')
        @parent.send(:get_hash_value, 'swift_version_requirements').should == [
          '3.0',
        ]
      end

      it 'stores swift version requirements as strings' do
        @parent.store_swift_version_requirements('>= 3.0', '< 4.0')
        @parent.send(:get_hash_value, 'swift_version_requirements').should == [
          '>= 3.0',
          '< 4.0',
        ]
      end

      it 'stores swift version requirements as an array of strings' do
        @parent.store_swift_version_requirements(['>= 3.0', '< 4.0'])
        @parent.send(:get_hash_value, 'swift_version_requirements').should == [
          '>= 3.0',
          '< 4.0',
        ]
      end

      it 'stores swift version requirements as versions' do
        @parent.store_swift_version_requirements(Version.new('3.0'), Version.new('4.0'))
        @parent.send(:get_hash_value, 'swift_version_requirements').should == [
          '3.0',
          '4.0',
        ]
      end

      it 'correctly returns whether a version of Swift is supported based on requirements' do
        @parent.store_swift_version_requirements('>= 3.0', '< 4.0')
        @parent.supports_swift_version?(Version.new('1.0')).should.be.false
        @parent.supports_swift_version?(Version.new('2.0')).should.be.false
        @parent.supports_swift_version?(Version.new('3.0')).should.be.true
        @parent.supports_swift_version?(Version.new('3.2')).should.be.true
        @parent.supports_swift_version?(Version.new('4.0')).should.be.false
      end

      it 'correclty returns whether a version of Swift is supported based on Version requirements' do
        @parent.store_swift_version_requirements(Version.new('3.0'))
        @parent.supports_swift_version?(Version.new('1.0')).should.be.false
        @parent.supports_swift_version?(Version.new('2.0')).should.be.false
        @parent.supports_swift_version?(Version.new('3.0')).should.be.true
        @parent.supports_swift_version?(Version.new('3.2')).should.be.false
        @parent.supports_swift_version?(Version.new('4.0')).should.be.false
      end

      it 'delegates to the parent for Swift version support if current target does not specify requirements' do
        @parent.store_swift_version_requirements('>= 3.0', '< 4.0')
        @child.supports_swift_version?(Version.new('1.0')).should.be.false
        @child.supports_swift_version?(Version.new('2.0')).should.be.false
        @child.supports_swift_version?(Version.new('3.0')).should.be.true
        @child.supports_swift_version?(Version.new('3.2')).should.be.true
        @child.supports_swift_version?(Version.new('4.0')).should.be.false
      end

      it 'returns the Swift version supported of the current target definition if specified' do
        @child.store_swift_version_requirements('>= 4.0')
        @parent.store_swift_version_requirements('>= 3.0', '< 4.0')
        @child.supports_swift_version?(Version.new('1.0')).should.be.false
        @child.supports_swift_version?(Version.new('2.0')).should.be.false
        @child.supports_swift_version?(Version.new('3.0')).should.be.false
        @child.supports_swift_version?(Version.new('3.2')).should.be.false
        @child.supports_swift_version?(Version.new('4.0')).should.be.true
        @child.supports_swift_version?(Version.new('4.2')).should.be.true
      end

      it 'accepts all Swift versions if no requirements are specified' do
        @parent.supports_swift_version?(Version.new('1.0')).should.be.true
        @parent.supports_swift_version?(Version.new('2.0')).should.be.true
        @parent.supports_swift_version?(Version.new('3.0')).should.be.true
        @parent.supports_swift_version?(Version.new('3.2')).should.be.true
        @parent.supports_swift_version?(Version.new('4.0')).should.be.true
      end

      #--------------------------------------#

      it 'stores a dependency on a pod as a sting if no requirements are provided' do
        @parent.store_pod('BlocksKit')
        @parent.send(:get_hash_value, 'dependencies').should == [
          'BlocksKit',
        ]
      end

      it 'stores a dependency on a pod as a hash if requirements provided' do
        @parent.store_pod('Reachability', '1.0')
        @parent.send(:get_hash_value, 'dependencies').should == [
          { 'Reachability' => ['1.0'] },
        ]
      end

      #--------------------------------------#

      it 'stores a dependency on a podspec' do
        @parent.store_podspec(:name => 'BlocksKit')
        @parent.send(:get_hash_value, 'podspecs').should == [
          { :name => 'BlocksKit' },
        ]
      end

      it 'stores a dependency on a podspec and sets is as auto-detect if no options are provided' do
        @parent.store_podspec
        @parent.send(:get_hash_value, 'podspecs').should == [
          { :autodetect => true },
        ]
      end

      it 'stores a dependency on a podspec\'s subspec' do
        @parent.store_podspec(:subspec => 'Subspec')
        @parent.send(:get_hash_value, 'podspecs').should == [
          { :autodetect => true,
            :subspec => 'Subspec',
           },
        ]
      end

      it 'stores a dependency on a podspec\'s subspecs' do
        @parent.store_podspec(:subspecs => ['Subspec'])
        @parent.send(:get_hash_value, 'podspecs').should == [
          { :autodetect => true,
            :subspecs => ['Subspec'],
           },
        ]
      end

      it 'raises if the provided podspec option type is error' do
        e = lambda { @parent.store_podspec(:subspec => 123) }.should.raise Podfile::StandardError
        e.message.should.match /should be a String/

        e = lambda { @parent.store_podspec(:subspecs => 123) }.should.raise Podfile::StandardError
        e.message.should.match /should be an Array of Strings/

        e = lambda { @parent.store_podspec(:subspecs => ['a', 123]) }.should.raise Podfile::StandardError
        e.message.should.match /should be an Array of Strings/
      end

      it 'raises if the provided podspec options are unsupported' do
        e = lambda { @parent.store_podspec(:invent => 'BlocksKit') }.should.raise Podfile::StandardError
        e.message.should.match /Unrecognized options/
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Hash representation' do
      it 'returns the hash representation' do
        @child.store_pod('BlocksKit')
        @child.set_platform(:ios)
        @child.to_hash.should == {
          'name' => 'MyAppTests',
          'abstract' => false,
          'inheritance' => 'search_paths',
          'dependencies' => ['BlocksKit'],
          'platform' => 'ios',
        }
      end

      it 'stores the children in the hash representation' do
        Podfile::TargetDefinition.new('MoarTests', @parent)
        @parent.store_pod('BlocksKit')
        @child.store_pod('RestKit')
        @parent.to_hash.should == {
          'name' => 'MyApp',
          'platform' => { 'ios' => '6.0' },
          'dependencies' => ['BlocksKit'],
          'children' => [
            {
              'name' => 'MyAppTests',
              'abstract' => false,
              'inheritance' => 'search_paths',
              'dependencies' => ['RestKit'],
            },
            {
              'name' => 'MoarTests',
            },
          ],
        }
      end

      it 'can be initialized from a hash' do
        @parent.store_pod('BlocksKit')
        @child.store_pod('RestKit')
        converted = Podfile::TargetDefinition.from_hash(@parent.to_hash, @podfile)
        converted.to_hash.should == @parent.to_hash
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Private helpers' do
      before do
        @parent.podfile.defined_in_file = SpecHelper::Fixture.fixture('Podfile')
      end

      #--------------------------------------#

      it 'sets and retrieves a value in the internal hash' do
        @parent.send(:set_hash_value, 'name', 'Fabio')
        @parent.send(:get_hash_value, 'name').should.equal 'Fabio'
      end

      it 'raises if there is an attempt to access or set an unknown key in the internal hash' do
        lambda { @parent.send(:set_hash_value, 'unknown', true) }.should.raise Pod::Podfile::StandardError
        lambda { @parent.send(:get_hash_value, 'unknown') }.should.raise Pod::Podfile::StandardError
      end

      it 'returns the dependencies specified by the user' do
        @parent.store_pod('BlocksKit')
        @parent.store_pod('AFNetworking', '1.0')
        dependencies = @parent.send(:pod_dependencies)
        dependencies.map(&:to_s).should == ['BlocksKit', 'AFNetworking (= 1.0)']
      end

      #--------------------------------------#

      describe '#pod_dependencies' do
        it 'handles dependencies which only indicate the name of the Pod' do
          @parent.store_pod('BlocksKit')
          @parent.send(:pod_dependencies).should == [
            Dependency.new('BlocksKit'),
          ]
        end

        it 'handles requirements' do
          @parent.store_pod('BlocksKit', '> 1.0', '< 2.5')
          @parent.send(:pod_dependencies).should == [
            Dependency.new('BlocksKit', ['> 1.0', '< 2.5']),
          ]
        end

        it 'handles subspecs' do
          @parent.store_pod('Spec/Subspec')
          @parent.send(:pod_dependencies).should == [
            Dependency.new('Spec/Subspec'),
          ]
        end

        it 'handles dependencies options' do
          @parent.store_pod('BlocksKit', :git => 'GIT-URL', :commit => '1234')
          @parent.send(:pod_dependencies).should == [
            Dependency.new('BlocksKit', :git => 'GIT-URL', :commit => '1234'),
          ]
        end
      end

      #--------------------------------------#

      describe '#podspec_dependencies' do
        it 'returns the dependencies of podspecs' do
          path = SpecHelper::Fixture.fixture('BananaLib.podspec').to_s
          @parent.store_podspec(:path => path)
          @parent.send(:podspec_dependencies).should == [
            Dependency.new('monkey', '< 1.0.9', '~> 1.0.1'),
            Dependency.new('AFNetworking'),
            Dependency.new('SDWebImage'),
          ]
        end

        it 'returns the dependencies of a subspec' do
          path = SpecHelper::Fixture.fixture('BananaLib.podspec').to_s
          @parent.store_podspec(:path => path, :subspec => 'GreenBanana')
          @parent.send(:podspec_dependencies).should == [
            Dependency.new('monkey', '< 1.0.9', '~> 1.0.1'),
            Dependency.new('AFNetworking'),
          ]
        end

        it 'reject the dependencies on subspecs' do
          path = SpecHelper::Fixture.fixture('BananaLib.podspec').to_s
          @parent.store_podspec(:path => path)
          external_dep = Dependency.new('monkey', '< 1.0.9', '~> 1.0.1')
          internal_dep = Dependency.new('BananaLib/subspec')
          deps = [external_dep, internal_dep]
          Specification.any_instance.stubs(:dependencies).returns([deps])
          @parent.send(:podspec_dependencies).should == [
            Dependency.new('monkey', '< 1.0.9', '~> 1.0.1'),
          ]
        end
      end

      #--------------------------------------#

      describe '#podspec_path_from_options' do
        it 'resolves a podspec given the absolute path' do
          options = { :path => SpecHelper::Fixture.fixture('BananaLib') }
          file = @parent.send(:podspec_path_from_options, options)
          file.should == SpecHelper::Fixture.fixture('BananaLib.podspec')
        end

        it 'resolves a podspec given the relative path' do
          options = { :path => 'BananaLib.podspec' }
          file = @parent.send(:podspec_path_from_options, options)
          file.should == SpecHelper::Fixture.fixture('BananaLib.podspec')
        end

        it 'add the extension if needed' do
          options = { :path => 'BananaLib' }
          file = @parent.send(:podspec_path_from_options, options)
          file.should == SpecHelper::Fixture.fixture('BananaLib.podspec')
        end

        it "doesn't add an extension for json podspecs" do
          options = { :path => 'BananaLib.podspec.json' }
          file = @parent.send(:podspec_path_from_options, options)
          file.should == SpecHelper::Fixture.fixture('BananaLib.podspec.json')
        end

        it 'it expands the tilde in the provided path' do
          home_dir = File.expand_path('~')
          options = { :path => '~/BananaLib.podspec' }
          file = @parent.send(:podspec_path_from_options, options)
          file.should == Pathname.new("#{home_dir}/BananaLib.podspec")
        end

        it 'resolves a podspec given its name' do
          options = { :name => 'BananaLib' }
          file = @parent.send(:podspec_path_from_options, options)
          file.should == SpecHelper::Fixture.fixture('BananaLib.podspec')
        end

        it "doesn't add an extension for json podspecs" do
          options = { :name => 'BananaLib.podspec.json' }
          file = @parent.send(:podspec_path_from_options, options)
          file.should == SpecHelper::Fixture.fixture('BananaLib.podspec.json')
        end

        it 'auto-detects the podspec' do
          options = { :autodetect => true }
          file = @parent.send(:podspec_path_from_options, options)
          file.should == SpecHelper::Fixture.fixture('BananaLib.podspec')
        end

        it 'raise an Informative error if the podspec cannot be auto-detected' do
          @parent.podfile.defined_in_file = SpecHelper::Fixture.fixture('podfile_without_root_podspec/Podfile')
          options = { :autodetect => true }
          e = lambda { @parent.send(:podspec_path_from_options, options) }.should.raise Pod::Informative
          e.message.should.match /Could not locate a podspec in the/
        end
      end
    end

    #-------------------------------------------------------------------------#
  end
end
