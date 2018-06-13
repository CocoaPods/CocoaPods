# Author: Arthur
# Email:  archmagees+cocoapods@gmail.com
# GitHub: https://github.com/archmagees
function get_commands
  for c in (commandline -opc)
    if not string match -q -- '-*' $c
      echo $c
    end
  end
end

function get_options
  for c in (commandline -opc)
    if string match -q -- '-*' $c
      echo $c
    end
  end
end

function commands_syntax_is
  set cmd (get_commands)
  set count (count $argv)

	# TODO: add check for --option=`empty`, that is options can NOT ending with
	# `=`

  if [ (count $cmd) -ne $count ]
    return 1
  end

  if test \( $count -ge 1 \) -a \( $argv[1] != $cmd[1] \)
    return 1
  end

  if test \( $count -ge 2 \) -a \( $argv[2] != $cmd[2] \)
    return 1
  end

  if test \( $count -ge 3 \) -a \( $argv[3] != $cmd[3] \)
    return 1
  end

  if test \( $count -ge 4 \) -a \( $argv[4] != $cmd[4] \)
    return 1
  end

  if test \( $count -ge 5 \) -a \( $argv[5] != $cmd[5] \)
    return 1
  end

  if test \( $count -ge 6 \) -a \( $argv[6] != $cmd[6] \)
    return 1
  end
  return 0
end

function commands_syntax_just_is
  set cmd (get_commands)
  set commands (commandline -opc)

  if [ (count $cmd) -ne (count $commands) ]
    return 1
  end

  if commands_syntax_is $argv
    return 0
  else
    return 1
  end
end

function argv_equal_cmd_at_index
	set cmd (commandline -opc)

	if [ $argv[1] = $cmd[$argv[2]] ]
		return 0
	end
	return 1
end

function commands_begin_with
	set commands (commandline -opc)
	if [ (count $argv) -gt (count $commands) ]
    return 1
  end

	set index 0
	for command in $argv
		set index (math $index + 1)

		# add command first
		# if [ $command = '*' ]
		# 	set command $commands[$index]
		# end
		if argv_equal_cmd_at_index $command $index
			continue
		else
			return 1
		end
	end
	return 0
end

function has_option
  set options (get_options)
  for option in $options
    if [ $option = $argv[1] ]
      return 0
    end
  end
  return 1
end

function excluded_options
  for argument in $argv
    if has_option $argument
      return 1
    else if has_option --help
      return 1
    else if has_option --version
      return 1
    end
  end
  return 0
end

function pod_install_with_excluded_options
  if commands_syntax_is pod install
    excluded_options $argv
    return $status
  end
  return 1
end

function pod_update_with_excluded_options
  if commands_syntax_is pod update
    excluded_options $argv
    return $status
  end
  return 1
end

function pod_trunk_push_with_excluded_options
  if commands_syntax_is pod trunk push
    excluded_options $argv
    return $status
  end
  return 1
end

function pod_trunk_register_with_excluded_options
  if commands_syntax_is pod trunk register
    excluded_options $argv
    return $status
  end
  return 1
end

function pod_trunk_me_clean-sessions_excluded_options
  if commands_syntax_is pod trunk me clean-sessions
    excluded_options $argv
    return $status
  end
  return 1
end

function pod_trunk_deprecate_excluded_options
  if commands_syntax_is pod trunk deprecate
    excluded_options $argv
    return $status
  end
  return 1
end

function pod_repo_add_excluded_options
  if commands_syntax_is pod repo add
    excluded_options $argv
    return $status
  end
  return 1
end

function pod_repo_lint_excluded_options
  if commands_syntax_is pod repo lint
    excluded_options $argv
    return $status
  end
  return 1
end

function pod_repo_list_excluded_options
  if commands_syntax_is pod repo list
    excluded_options $argv
    return $status
  end
  return 1
end

function pod_repo_push_excluded_options
  set cmd (commandline -opc)
  set repos (pod_repo_list)
  for r in $repos
    if commands_syntax_is pod repo push $r
      excluded_options $argv
      return $status
    end
  end
  return 1
end

function pod_search_name_with_excluded_options
  set cmd (commandline -opc)
  if [ (count $cmd) -le 2 ]
    return 1
  end

  if commands_syntax_is pod search $cmd[3]
    excluded_options $argv
    return $status
  end
  return 1
end

function pod_cache_with_command
	set cmd (commandline -opc)
	if commands_begin_with pod cache $argv[1]
		if not set -q cmd[4]
			return 0
		else
			set -e cmd[1..3]
			set cache_list (pod_cache_list)
			for pod in $cmd
				if not contains $pod $cache_list
					return 1
				end
			end
		return 0
		end
	end
	return 1
end

function pod_cache_clean_excluded_options
	if commands_begin_with pod cache clean
		excluded_options $argv
		return $status
	end
	return 1
end

function pod_cache_list_excluded_options
	if commands_begin_with pod cache list
		excluded_options $argv
		return $status
	end
	return 1
end

function pod_deintegrate_excluded_options
	if commands_syntax_is pod deintegrate
		excluded_options $argv
		return $status
	end
	return 1
end

function pod_deploy_excluded_options
	if commands_syntax_is pod deploy
		excluded_options $argv
		return $status
	end
	return 1
end

function pod_lib_create_excluded_options
	if commands_begin_with pod lib create
		set cmd (commandline -opc)
		if not set -q cmd[4]
			return 1
		end
		excluded_options $argv
		return $status
	end
	return 1
end

function pod_lib_lint_excluded_options
	if commands_syntax_is pod lib lint
		excluded_options $argv
		return $status
	end

	if commands_syntax_is pod spec lint
		excluded_options $argv
		return $status
	end

	return 1
end

function pod_list_excluded_options
	if commands_syntax_is pod list
		excluded_options $argv
		return $status
	end
	return 1
end

function pod_outdated_excluded_options
	if commands_syntax_is pod outdated
		excluded_options $argv
		return $status
	end
	return 1
end

function pod_package_excluded_options
	if commands_syntax_is pod package
		excluded_options $argv
		return $status
	end
	return 1
end

function pod_spec_command_exclued_options
	if commands_syntax_is pod spec $argv[1]
		set n (count $argv)
		excluded_options $argv[2..$n]
		return $status
	end
	return 1
end

function pod_try_NAMEorURL_excluded_options
	if commands_begin_with pod try
		set cmd (commandline -opc)
		if not set -q cmd[3]
			return 1
		end
		excluded_options $argv
		return $status
	end
	return 1
end

function has_project-directory_option_commands_which_syntax_is
	if commands_syntax_is $argv
		excluded_options --project-directory=
		return $status
	end
	return 1
end

function has_no_options
  for c in (commandline -opc)
    if string match -q -- '-*' $c
      return 1
    end
  end
  return 0
end

function at_least_two_commands_with_excluded_options
  set commands (get_commands)
  if [ (count $commands) -le 1 ]
    return 1
  end
  excluded_options $argv
  return $status
end

function silent_option_with_excluded_options
	set cmd (commandline -opc)
  if commands_syntax_is pod search $cmd[3]
    return 1
  end

	if commands_syntax_is pod env $cmd[3]
		return 1
	end

  at_least_two_commands_with_excluded_options $argv
  return $status
end

function podspec_files
	ls . | grep .podspec | xargs echo
end

function pod_repo_list
  ls ~/.cocoapods/repos/.
end

function pod_cache_list
	ls ~/Library/Caches/CocoaPods/Pods/External
	ls ~/Library/Caches/CocoaPods/Pods/Release
end


################################################################################
# default options
complete -c pod -f -a '' -r

# pod --version
complete -c pod -n 'commands_syntax_just_is pod' -f -l version -f -d 'Show the version of the tool' -f
# pod --help
complete -c pod -n 'has_no_options' -f -l help -d 'Show help banner of specified command' -f

### pod command --verbose
complete -c pod -n 'at_least_two_commands_with_excluded_options --verbose --silent --count-only' -f -l verbose -d 'Show more debugging information' -f

### pod command --silent
complete -c pod -n 'silent_option_with_excluded_options --verbose --silent --progress --no-ansi --count-only --stats' -f -l silent -d 'Show nothing' -f

### pod command --no-ansi
complete -c pod -n 'at_least_two_commands_with_excluded_options --silent --no-ansi --count-only' -f -l no-ansi -d 'Show output without ANSI codes' -f

### IMPORTANT
# -f -a "" -r makes pod install <tab> will NOT complete with file


################################################################################
# pod init
complete -c pod -n 'commands_syntax_just_is pod' -f -a init -r -d 'Generate a Podfile for the current directory' -r
complete -c pod -n 'commands_syntax_is pod init' -f -a '' -r

################################################################################
# pod install
complete -c pod -n 'commands_syntax_just_is pod' -f -a 'install' -r -d 'Install project dependencies according to versions from a Podfile.lock' -r
complete -c pod -n 'commands_syntax_is pod install' -f -a '' -r
complete -c pod -n 'pod_install_with_excluded_options --repo-update' -l repo-update -d 'Force running `pod repo update` before install' -r
complete -c pod -n 'pod_install_with_excluded_options --project-directory' -l project-directory -d 'The path to the root of the project directory' -x

################################################################################
# pod update
complete -c pod -n 'commands_syntax_just_is pod' -a 'update' -d 'Update outdated project dependencies and create new Podfile.lock' -r
complete -c pod -n 'commands_syntax_is pod update' -f -a '' -r
complete -c pod -n 'pod_update_with_excluded_options --sources' -l sources -d 'The sources from which to update dependent pods. Multiple sources must be comma-delimited. The master repo will not be included by default with this option.' -r
complete -c pod -n 'pod_update_with_excluded_options --exclude-pods' -l exclude-pods -d 'Pods to exclude during update. Multiple pods must be comma-delimited.' -r
complete -c pod -n 'pod_update_with_excluded_options --project-directory' -l project-directory -d 'The path to the root of the project directory' -r
complete -c pod -n 'pod_update_with_excluded_options --no-repo-update' -l no-repo-update -d 'Skip running `pod repo update` before install' -r

################################################################################
# pod trunk
complete -c pod -n 'commands_syntax_just_is pod' -a trunk -d 'Interact with the CocoaPods API (e.g. publishing new specs)' -r
complete -c pod -n 'commands_syntax_just_is pod trunk' -f -a add-owner -d 'Add an owner to a pod' -r
complete -c pod -n 'commands_syntax_just_is pod trunk' -f -a delete -d 'Deletes a version of a pod.' -r
complete -c pod -n 'commands_syntax_just_is pod trunk' -f -a deprecate -d 'Deprecates a pod.' -r
complete -c pod -n 'commands_syntax_just_is pod trunk' -f -a info -d 'Returns information about a Pod.' -r
complete -c pod -n 'commands_syntax_just_is pod trunk' -f -a me -d 'Display information about your sessions' -r
complete -c pod -n 'commands_syntax_just_is pod trunk' -f -a push -d 'Publish a podspec' -r
complete -c pod -n 'commands_syntax_just_is pod trunk' -f -a register -d 'Manage sessions' -r
complete -c pod -n 'commands_syntax_just_is pod trunk' -f -a remove-owner -d 'Remove an owner from a pod' -r

### pod trunk push
complete -c pod -n 'pod_trunk_push_with_excluded_options --allow-warnings' -l allow-warnings -d 'Allows push even if there are lint warnings' -r
complete -c pod -n 'pod_trunk_push_with_excluded_options --use-libraries' -l use-libraries -d 'Linter uses static libraries to install the spec' -r
complete -c pod -n 'pod_trunk_push_with_excluded_options --swift_version=' -l swift_version= -d 'The SWIFT_VERSION that should be used to lint the spec.\nThis takes precedence over a .swift-version file.' -r
complete -c pod -n 'pod_trunk_push_with_excluded_options --skip-import-validation' -l skip-import-validation -d 'Lint skips validating that the pod can be imported' -r
complete -c pod -n 'pod_trunk_push_with_excluded_options --skip-tests' -l skip-tests -d 'Lint skips building and running tests during validation' -r

### pod trunk register
complete -c pod -n 'pod_trunk_register_with_excluded_options --description=' -l description= -d 'An arbitrary description to easily identify your session later on.' -r

### pod trunk me
complete -c pod -n 'commands_syntax_just_is pod trunk me' -f -a clean-sessions -d 'Remove sessions' -r
complete -c pod -n 'pod_trunk_me_clean-sessions_excluded_options --all' -l all -d 'Removes all your sessions, except for the current one' -r

### pod trunk deprecate
complete -c pod -n 'pod_trunk_deprecate_excluded_options --in-favor-of=' -r -l in-favor-of= -d 'The pod to deprecate this pod in favor of.' -r

################################################################################
# pod repo
complete -c pod -n 'commands_syntax_just_is pod' -f -a repo -d 'Manage spec-repositories' -r
complete -c pod -n 'commands_syntax_just_is pod repo' -f -a add -d 'Add a spec repo' -r
complete -c pod -n 'commands_syntax_just_is pod repo' -f -a lint -d 'Validates all specs in a repo' -r
complete -c pod -n 'commands_syntax_just_is pod repo' -f -a list -d 'List repos' -r
complete -c pod -n 'commands_syntax_just_is pod repo' -f -a push -d 'Push new specifications to a spec-repo' -r
complete -c pod -n 'commands_syntax_just_is pod repo' -f -a remove -d 'Remove a spec repo' -r
complete -c pod -n 'commands_syntax_just_is pod repo' -f -a update -d 'Update a spec repo' -r

### pod repo add
complete -c pod -n 'pod_repo_add_excluded_options --progress --silent' -l progress -d 'Show the progress of cloning the spec repository' -r

### pod repo lint
complete -c pod -n 'pod_repo_lint_excluded_options --only-errors' -l only-errors -d 'Lint presents only the errors' -r

### pod repo list
complete -c pod -n 'pod_repo_list_excluded_options --count-only' -l count-only -d 'Show the total number of repos' -r

### pod repo push
complete -c pod -n 'commands_syntax_just_is pod repo push' -f -a '(pod_repo_list)' -r
complete -c pod -n 'pod_repo_push_excluded_options --allow-warnings' -l allow-warnings -d 'Allows pushing even if there are warnings' -r
complete -c pod -n 'pod_repo_push_excluded_options --use-libraries' -l use-libraries -d 'Linter uses static libraries to install the spec' -r
complete -c pod -n 'pod_repo_push_excluded_options --sources=' -l sources= -d 'The sources from which to pull dependent pods (defaults to all available repos). Multiple sources must be comma-delimited.' -r
complete -c pod -n 'pod_repo_push_excluded_options --local-only' -l local-only -d 'Does not perform the step of pushing REPO to its remote' -r
complete -c pod -n 'pod_repo_push_excluded_options --no-private' -l no-private -d 'Lint includes checks that apply only to public repos' -r
complete -c pod -n 'pod_repo_push_excluded_options --skip-import-validation' -l skip-import-validation -d 'Lint skips validating that the pod can be imported' -r
complete -c pod -n 'pod_repo_push_excluded_options --skip-tests' -l skip-tests -d 'Lint skips building and running tests during validation' -r
complete -c pod -n 'pod_repo_push_excluded_options --commit-message' -l commit-message -d 'Add custom commit message. Opens default editor if no commit message is specified.' -r
complete -c pod -n 'pod_repo_push_excluded_options --use-json' -l use-json -d 'Push JSON spec to repo' -r
complete -c pod -n 'pod_repo_push_excluded_options --swift_version' -l swift_version -d 'The SWIFT_VERSION that should be used when linting the spec. This takes precedence over a .swift-version file.' -r
complete -c pod -n 'pod_repo_push_excluded_options --no-overwrite' -l no-overwrite -d 'Disallow pushing that would overwrite an existing spec.' -r

### pod repo remove
complete -c pod -n 'commands_syntax_just_is pod repo remove' -f -a '(pod_repo_list)' -r

### pod repo update
complete -c pod -n 'commands_syntax_just_is pod repo update' -f -a '(pod_repo_list)' -r

################################################################################
# pod search
complete -c pod -n 'commands_syntax_just_is pod' -a search -d 'Search for pods' -r
complete -c pod -n 'pod_search_name_with_excluded_options --regex' -l regex -d 'Interpret the `QUERY` as a regular expression' -r
complete -c pod -n 'pod_search_name_with_excluded_options --simple' -l simple -d 'Search only by name' -r
complete -c pod -n 'pod_search_name_with_excluded_options --stats --silent' -l stats -d 'Show additional stats (like GitHub watchers and forks)' -r
complete -c pod -n 'pod_search_name_with_excluded_options --web' -l web -d 'Searches on cocoapods.org' -r
complete -c pod -n 'pod_search_name_with_excluded_options --ios --osx --watchos --tvos' -l ios -d 'Restricts the search to Pods supported on iOS' -r
complete -c pod -n 'pod_search_name_with_excluded_options --ios --osx --watchos --tvos' -l osx -d 'Restricts the search to Pods supported on macOS' -r
complete -c pod -n 'pod_search_name_with_excluded_options --ios --osx --watchos --tvos' -l watchos -d 'Restricts the search to Pods supported on watchOS' -r
complete -c pod -n 'pod_search_name_with_excluded_options --ios --osx --watchos --tvos' -l tvos -d 'Restricts the search to Pods supported on tvOS' -r
complete -c pod -n 'pod_search_name_with_excluded_options --no-pager' -l no-pager -d 'Do not pipe search results into a pager' -r

################################################################################
# pod cache
complete -c pod -n 'commands_syntax_just_is pod' -f -a cache -d 'Manipulate the CocoaPods cache' -r
complete -c pod -n 'commands_syntax_just_is pod cache' -f -a clean -d 'Remove the cache for pods' -r
complete -c pod -n 'commands_syntax_just_is pod cache' -f -a list -d 'List the paths of pod caches for each known pod' -r

### pod cache clean
complete -c pod -n 'commands_begin_with pod cache clean' -f -a '(pod_cache_list)' -r
complete -c pod -n 'pod_cache_clean_excluded_options --all' -f -l all -d 'Remove all the cached pods without asking' -r

### pod cache list
complete -c pod -n 'commands_begin_with pod cache list' -f -a '(pod_cache_list)' -r
complete -c pod -n 'pod_cache_list_excluded_options --short' -f -l short -d 'Only print the path relative to the cache root' -r

################################################################################
# pod deintegrate
complete -c pod -n 'commands_syntax_just_is pod' -f -a deintegrate -d 'Deintegrate CocoaPods from your project' -r
complete -c pod -n  'pod_deintegrate_excluded_options --project-directory=' -f -l project-directory= -d 'The path to the root of the project directory' -r

################################################################################
# pod deploy
complete -c pod -n 'commands_syntax_just_is pod' -f -a deploy -d 'Install project dependencies to Podfile.lock versions without pulling down full podspec repo.' -r
complete -c pod -n  'pod_deploy_excluded_options --project-directory=' -f -l project-directory= -d 'The path to the root of the project directory' -r

################################################################################
# pod env
complete -c pod -n 'commands_syntax_just_is pod' -f -a env -d 'Display pod environment' -r

################################################################################
# pod ipc
complete -c pod -n 'commands_syntax_just_is pod' -f -a ipc -d 'Inter-process communication' -r

### pod ipc list
complete -c pod -n 'commands_syntax_is pod ipc' -f -a list -d 'Lists the specifications known to CocoaPods' -r

### pod ipc podfile
complete -c pod -n 'commands_syntax_is pod ipc' -f -a podfile -d 'Converts a Podfile to YAML' -r
complete -c pod -n 'has_project-directory_option_commands_which_syntax_is pod ipc podfile' -f -l project-directory= -d 'The path to the root of the project directory' -r

### pod ipc podfile-json
complete -c pod -n 'commands_syntax_just_is pod ipc' -f -a podfile-json -d 'Converts a Podfile to JSON' -r
complete -c pod -n 'has_project-directory_option_commands_which_syntax_is pod ipc podfile-json' -f -l project-directory= -d 'The path to the root of the project directory' -r

### pod ipc repl
complete -c pod -n 'commands_syntax_just_is pod ipc' -f -a repl -d 'The repl listens to commands on standard input' -r
complete -c pod -n 'has_project-directory_option_commands_which_syntax_is pod ipc repl' -f -l project-directory= -d 'The path to the root of the project directory' -r

### pod ipc spec
complete -c pod -n 'commands_syntax_just_is pod ipc' -f -a spec -d 'Converts a podspec to JSON' -r

### pod ipc update-search-index
complete -c pod -n 'commands_syntax_just_is pod ipc' -f -a update-search-index -d 'Updates the search index' -r

################################################################################
# pod lib
complete -c pod -n 'commands_syntax_just_is pod' -f -a lib -d 'Develop pods' -r
complete -c pod -n 'commands_syntax_is pod lib' -f -a create -d 'Creates a new Pod' -r
complete -c pod -n 'commands_syntax_is pod lib' -f -a lint -d 'Validates a Pod'

### pod lib create NAME
complete -c pod -n 'pod_lib_create_excluded_options --template-url=' -f -l template-url= -d 'The URL of the git repo containing a compatible template' -r

### pod lib lint
complete -c pod -n 'pod_lib_lint_excluded_options --quick' -f -l quick -d 'Lint skips checks that would require to download and build the spec' -r
complete -c pod -n 'pod_lib_lint_excluded_options --allow-warnings' -f -l allow-warnings -d 'Lint validates even if warnings are present' -r
complete -c pod -n 'pod_lib_lint_excluded_options --subspec=' -f -l subspec= -d 'Lint validates only the given subspec' -r
complete -c pod -n 'pod_lib_lint_excluded_options --no-specs' -f -l no-specs -d 'Lint skips validation of subspecs' -r
complete -c pod -n 'pod_lib_lint_excluded_options --no-clean' -f -l no-clean -d 'Lint leaves the build directory intact for inspection' -r
complete -c pod -n 'pod_lib_lint_excluded_options --fail-fast' -f -l fail-fast -d 'Lint stops on the first failing platform or subspec' -r
complete -c pod -n 'pod_lib_lint_excluded_options --use-libraries' -f -l use-libraries -d 'Lint uses static libraries to install the spec' -r
complete -c pod -n 'pod_lib_lint_excluded_options --sources=' -f -l sources= -d 'The sources from which to pull dependent pods (defaults to https://github.com/CocoaPods/Specs.git). Multiple sources must be comma-delimited.' -r
complete -c pod -n 'pod_lib_lint_excluded_options --private' -f -l private -d 'Lint skips checks that apply only to public specs' -r
complete -c pod -n 'pod_lib_lint_excluded_options --swift_version' -f -l swift-version -d 'The SWIFT_VERSION that should be This takes precedence over a .swift-version file.' -r
complete -c pod -n 'pod_lib_lint_excluded_options --skip-import-validation' -f -l skip-import-validation -d 'Lint skips validating that the pod can be imported' -r
complete -c pod -n 'pod_lib_lint_excluded_options --skip-tests' -f -l skip-tests -d 'Lint skips building and running tests during validation' -r

################################################################################
##### pod list
complete -c pod -n 'commands_syntax_just_is pod' -f -a list -d 'List pods' -r
complete -c pod -n 'pod_list_excluded_options --update' -f -l update -d 'Run `pod repo update` before listing' -r
complete -c pod -n 'pod_list_excluded_options --stats --silent' -f -l stats -d 'Show additional stats (like GitHub watchers and forks)' -r

################################################################################
##### pod outdated
complete -c pod -n 'commands_syntax_just_is pod' -f -a outdated -d 'Show outdated project dependencies' -r
complete -c pod -n 'has_project-directory_option_commands_which_syntax_is pod outdated' -f -l project-directory= -d 'The path to the root of the project directory' -r
complete -c pod -n 'pod_outdated_excluded_options --no-repo-update' -f -l no-repo-update -d 'Skip running `pod repo update` before install' -r

################################################################################
##### pod package
complete -c pod -n 'commands_syntax_just_is pod' -f -a package -d 'Package a podspec into a static library.' -r
complete -c pod -n 'commands_syntax_is pod package' -f -a NAME -r
# complete -c pod -n 'commands_begin_with pod package *' -f -a '(podspec_files)' -r
complete -c pod -n 'pod_package_excluded_options --force' -f -l force -d 'Overwrite existing files.' -r
complete -c pod -n 'pod_package_excluded_options --no-mangle' -f -l no-mangle -d 'Do not mangle symbols of Pods.' -r
complete -c pod -n 'pod_package_excluded_options --embedded' -f -l embedded -d 'Generate embedded frameworks.' -r
complete -c pod -n 'pod_package_excluded_options --library' -f -l library -d 'Generate static libraries.' -r
complete -c pod -n 'pod_package_excluded_options --dynamic' -f -l dynamic -d 'Generate dynamic framework.' -r
complete -c pod -n 'pod_package_excluded_options --bundle-identifier' -f -l bundle-identifier -d 'Bundle identifier for dynamic' -r
complete -c pod -n 'pod_package_excluded_options --exclude-deps' -f -l exclude-deps -d 'Exclude symbols from dependencie .' -r
complete -c pod -n 'pod_package_excluded_options --configuration' -f -l configuration -d 'Build the specified configuration Debug). Defaults to Release' -r
complete -c pod -n 'pod_package_excluded_options --subspecs' -f -l subspecs -d 'Only include the given subspecs' -r
complete -c pod -n 'pod_package_excluded_options --spec-sources=' -f -l spec-sources= -d 'The sources to pull dependant pods from (defaults to https://github.com/CocoaPods/Specs.git)' -r

################################################################################
### pod setup
complete -c pod -n 'commands_syntax_just_is pod' -f -a setup -d 'Setup the CocoaPods environment' -r

################################################################################
### pod spec
complete -c pod -n 'commands_syntax_just_is pod' -f -a spec -d 'Manage pod specs' -r
complete -c pod -n 'commands_syntax_just_is pod spec' -f -a cat -d 'Prints a spec file' -r
complete -c pod -n 'commands_syntax_just_is pod spec' -f -a create -d 'Create spec file stub.' -r
complete -c pod -n 'commands_syntax_just_is pod spec' -f -a edit -d 'Edit a spec file' -r
complete -c pod -n 'commands_syntax_just_is pod spec' -f -a lint -d 'Validates a spec file' -r
complete -c pod -n 'commands_syntax_just_is pod spec' -f -a which -d 'Prints the path of the given spec' -r

# pod spec cat
complete -c pod -n 'pod_spec_command_exclued_options cat --regex' -f -l regex -d 'Interpret the `QUERY` as a regular expression' -r
complete -c pod -n 'pod_spec_command_exclued_options cat --show-all' -f -l show-all -d 'Pick from all versions of the given podspec' -r

# pod spec create NAMEorGitHubURL
complete -c pod -n 'commands_syntax_just_is pod spec create' -f -a "NAMEorGitHubURL" -f

# pod spec edit
complete -c pod -n 'pod_spec_command_exclued_options edit --regex' -f -l regex -d 'Interpret the `QUERY` as a regular expression' -r
complete -c pod -n 'pod_spec_command_exclued_options edit --show-all' -f -l show-all -d 'Pick from all versions of the given podspec' -r

# pod spec lint is using pod lib lint

# pod spec which
complete -c pod -n 'pod_spec_command_exclued_options which --regex' -f -l regex -d 'Interpret the `QUERY` as a regular expression' -r
complete -c pod -n 'pod_spec_command_exclued_options which --show-all' -f -l show-all -d 'Pick from all versions of the given podspec' -r

################################################################################
### pod try
complete -c pod -n 'commands_syntax_just_is pod' -f -a try -d 'Try a Pod!' -r
complete -c pod -n 'commands_syntax_is pod try' -f -a NAMEorURL -r
complete -c pod -n 'pod_try_NAMEorURL_excluded_options --podspec_name=' -f -l podspec_name= -d 'The name of the podspec file within the Git Repository' -r
complete -c pod -n 'pod_try_NAMEorURL_excluded_options --no-repo-update' -f -l no-repo-update -d 'Skip running `pod repo update` before install' -r
