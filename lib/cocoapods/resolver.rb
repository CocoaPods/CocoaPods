require 'tsort'
require 'forwardable'
require 'pry'

module Pod
  class Specification
    def required_by
      @required_by ||= []
    end
  end
  class Dependency
    def required_by
      @required_by ||= []
    end
  end
end

module Pod
  class VersionConflict  < StandardError
      attr_reader :conflicts

      def initialize(conflicts, msg = nil)
        super(msg)
        @conflicts = conflicts
      end

      def self.status_code; 6 end
    end
  class LazySpecification

      attr_reader :name, :version, :dependencies, :platform
      attr_accessor :source, :source_uri

      def initialize(name, version, platform, source = nil)
        @name          = name
        @version       = version
        @dependencies  = []
        @platform      = platform
        @source        = source
        @specification = nil
      end

      def full_name
        if platform == Gem::Platform::RUBY or platform.nil? then
          "#{@name}-#{@version}"
        else
          "#{@name}-#{@version}-#{platform}"
        end
      end

      def ==(other)
        identifier == other.identifier
      end

      def satisfies?(dependency)
        @name == dependency.name && dependency.requirement.satisfied_by?(Gem::Version.new(@version))
      end

      def to_lock
        if platform == Gem::Platform::RUBY or platform.nil?
          out = "    #{name} (#{version})\n"
        else
          out = "    #{name} (#{version}-#{platform})\n"
        end

        dependencies.sort_by {|d| d.to_s }.each do |dep|
          next if dep.type == :development
          out << "    #{dep.to_lock}\n"
        end

        out
      end

      def __materialize__
        @specification = source.specs.search(Gem::Dependency.new(name, version)).last
      end

      def respond_to?(*args)
        super || @specification.respond_to?(*args)
      end

      def to_s
        @__to_s ||= "#{name} (#{version})"
      end

      def identifier
        @__identifier ||= [name, version, source, platform, dependencies].hash
      end

      def match_platform(p)
        platform.supports?(p)
      end

    private

      def to_ary
        nil
      end

      def method_missing(method, *args, &blk)
        raise "LazySpecification has not been materialized yet (calling :#{method} #{args.inspect})" unless @specification

        return super unless respond_to?(method)

        @specification.send(method, *args, &blk)
      end

    end

  class DepProxy

      attr_reader :required_by, :__platform, :dep

      def initialize(dep, platform)
        @dep, @__platform, @required_by = dep, platform, []
      end

      def hash
        @hash ||= dep.hash
      end

      def ==(o)
        dep == o.dep && __platform == o.__platform
      end

      alias eql? ==

      def type
        @dep.type
      end

      def is_a?(t)
        super || @dep.is_a?(t)
      end

      def name
        @dep.name
      end

      def requirement
        @dep.requirement
      end

      def to_s
        "#{name} (#{requirement}) #{__platform}"
      end

    private

      def method_missing(*args)
        @dep.send(*args)
      end

    end

  class SpecSet
    extend Forwardable
    include TSort, Enumerable

    def_delegators :@specs, :<<, :length, :add, :remove
    def_delegators :sorted, :each

    def initialize(specs)
      @specs = specs.sort_by { |s| s.name }
    end

    def for(dependencies, skip = [], check = false, match_current_platform = false)
      handled, deps, specs = {}, dependencies.dup, []
      skip << 'bundler'

      until deps.empty?
        dep = deps.shift
        next if handled[dep] || skip.include?(dep.name)

        spec = lookup[dep.name].find do |s|
          if match_current_platform
            Gem::Platform.match(s.platform)
          else
            s.match_platform(dep.__platform)
          end
        end

        handled[dep] = true

        if spec
          specs << spec

          spec.dependencies.each do |d|
            d = DepProxy.new(d, Platform.ios) unless match_current_platform
            deps << d
          end
        elsif check
          return false
        end
      end

      if spec = lookup['bundler'].first
        specs << spec
      end

      check ? true : SpecSet.new(specs)
    end

    def valid_for?(deps)
      self.for(deps, [], true)
    end

    def [](key)
      key = key.name if key.respond_to?(:name)
      lookup[key].reverse
    end

    def []=(key, value)
      @specs << value
      @lookup = nil
      @sorted = nil
      value
    end

    def sort!
      self
    end

    def to_a
      sorted.dup
    end

    def to_hash
      lookup.dup
    end

    def materialize(deps, missing_specs = nil)
      materialized = self.for(deps, [], false, true).to_a
      deps = materialized.map {|s| s.name }.uniq
      materialized.map! do |s|
        next s unless s.is_a?(LazySpecification)
        s.source.dependency_names = deps if s.source.respond_to?(:dependency_names=)
        spec = s.__materialize__
        if missing_specs
          missing_specs << s unless spec
        else
          raise GemNotFound, "Could not find #{s.full_name} in any of the sources" unless spec
        end
        spec if spec
      end
      SpecSet.new(materialized.compact)
    end

    def merge(set)
      arr = sorted.dup
      set.each do |s|
        next if arr.any? { |s2| s2.name == s.name && s2.version == s.version && s2.platform == s.platform }
        arr << s
      end
      SpecSet.new(arr)
    end

  private

    def sorted
      rake = @specs.find { |s| s.name == 'rake' }
      begin
        @sorted ||= ([rake] + tsort).compact.uniq
      rescue TSort::Cyclic => error
        cgems = extract_circular_gems(error)
        raise CyclicDependencyError, "Your Gemfile requires gems that depend" \
          " depend on each other, creating an infinite loop. Please remove" \
          " either gem '#{cgems[1]}' or gem '#{cgems[0]}' and try again."
      end
    end

    def extract_circular_gems(error)
      if Bundler.current_ruby.mri? && Bundler.current_ruby.on_19?
        error.message.scan(/(\w+) \([^)]/).flatten
      else
        error.message.scan(/@name="(.*?)"/).flatten
      end
    end

    def lookup
      @lookup ||= begin
        lookup = Hash.new { |h,k| h[k] = [] }
        specs = @specs.sort_by do |s|
          s.platform.to_s == 'ruby' ? "\0" : s.platform.to_s
        end
        specs.reverse_each do |s|
          lookup[s.name] << s
        end
        lookup
      end
    end

    def tsort_each_node
      @specs.each { |s| yield s }
    end

    def tsort_each_child(s)
      s.dependencies.sort_by { |d| d.name }.each do |d|
        lookup[d.name].each { |s2| yield s2 }
      end
    end
  end
end

module Pod
  class Resolver

    class SpecGroup < Array

      ALL = %w(ios osx).map { |p| Platform.new(p) }.freeze

      attr_reader :activated, :required_by

      def initialize(a)
        super
        @required_by  = []
        @activated    = []
        @dependencies = nil
        @specs        = Hash.new { |hash, key| hash.assoc(key)[1] }

        ALL.each do |p|
          @specs[p] = reverse.find { |s| s.supported_on_platform?(p) }
        end
      end

      def initialize_copy(o)
        super
        @required_by = o.required_by.dup
        @activated   = o.activated.dup
      end

      def to_specs
        specs = {}

        @activated.each do |p|
          if s = @specs[p]
            platform = Platform.ios
            next if specs[platform]

            lazy_spec = LazySpecification.new(name, version, platform, source)
            lazy_spec.dependencies.replace s.dependencies
            specs[platform] = lazy_spec
          end
        end
        specs.values
      end

      def activate_platform(platform)
        unless @activated.include?(platform)
          @activated << platform
          return __dependencies[platform] || []
        end
        []
      end

      def name
        @name ||= first.name
      end

      def version
        @version ||= first.version
      end

      def source
        @source ||= first.source
      end

      def for?(platform)
        @specs[platform]
      end

      def to_s
        "#{name} (#{version})"
      end

    private

      def __dependencies
        @dependencies ||= begin
          dependencies = Hash.new { |hash, key| hash.assoc(key)[1] }
          ALL.each do |p|
            if spec = @specs[p]
              dependencies[p] = []
              spec.all_dependencies.each do |dep|
                dependencies[p] << DepProxy.new(dep, p)
              end
            end
          end
          dependencies
        end
      end
    end

    attr_reader :errors, :started_at, :iteration_rate, :iteration_counter

    # Figures out the best possible configuration of gems that satisfies
    # the list of passed dependencies and any child dependencies without
    # causing any gem activation errors.
    #
    # ==== Parameters
    # *dependencies<Dependency>:: The list of dependencies to resolve
    #
    # ==== Returns
    # <GemBundle>,nil:: If the list of dependencies can be resolved, a
    #   collection of gemspecs is returned. Otherwise, nil is returned.
    def self.resolve(requirements, index, source_requirements = {}, base = [])
      UI.message "Resolving dependencies..."
      base = SpecSet.new(base) unless base.is_a?(SpecSet)
      resolver = new(index, source_requirements, base)
      result = resolver.start(requirements)
      UI.message "" # new line now that dots are done
      SpecSet.new(result)
    rescue => e
      UI.message "" do # new line before the error
        raise e
      end
    end

    def initialize(index, source_requirements, base)
      @errors               = {}
      @stack                = []
      @base                 = base
      @index                = index
      @deps_for             = {}
      @missing_gems         = Hash.new(0)
      @source_requirements  = source_requirements
      @iteration_counter    = 0
      @started_at           = Time.now
    end

    def debug
      if ENV['DEBUG_RESOLVER']
        debug_info = yield
        debug_info = debug_info.inspect unless debug_info.is_a?(String)
        $stderr.puts debug_info
      end
    end

    def successify(activated)
      activated.values.map { |s| s.to_specs }.flatten.compact
    end

    def start(reqs)
      activated = {}
      @gems_size = Hash[reqs.map { |r| [r, gems_size(r)] }]

      resolve(reqs, activated)
    end

    class State < Struct.new(:reqs, :activated, :requirement, :possibles, :depth)
      def name
        requirement.name
      end
    end

    def handle_conflict(current, states, existing=nil)
      until current.nil? && existing.nil?
        current_state = find_state(current, states)
        existing_state = find_state(existing, states)
        return current if state_any?(current_state)
        return existing if state_any?(existing_state)
        existing = existing.required_by.last if existing
        current = current.required_by.last if current
      end
    end

    def state_any?(state)
      state && state.possibles.any?
    end

    def find_state(current, states)
      states.detect { |i| current && current.name == i.name }
    end

    def other_possible?(conflict, states)
      return unless conflict
      state = states.detect { |i| i.name == conflict.name }
      state && state.possibles.any?
    end

    def find_conflict_state(conflict, states)
      return unless conflict
      until states.empty? do
        state = states.pop
        return state if conflict.name == state.name
      end
    end

    def activate_gem(reqs, activated, requirement, current)
      requirement.required_by.replace current.required_by
      requirement.required_by << current
      activated[requirement.name] = requirement

      debug { "  Activating: #{requirement.name} (#{requirement.version})" }
      debug { requirement.required_by.map { |d| "    * #{d.name} (#{d.requirement})" }.join("\n") }

      dependencies = requirement.activate_platform(Platform.ios)
      debug { "    Dependencies"}
      dependencies.each do |dep|
        dep.required_by.replace(current.required_by)
        dep.required_by << current
        @gems_size[dep] ||= gems_size(dep)
        reqs << dep
      end
    end

    def resolve_for_conflict(state)
      raise version_conflict if state.nil? || state.possibles.empty?
      reqs, activated, depth = state.reqs.dup, state.activated.dup, state.depth
      requirement = state.requirement
      possible = state.possibles.pop

      activate_gem(reqs, activated, possible, requirement)

      return reqs, activated, depth
    end

    def resolve_conflict(current, states)
      # Find the state where the conflict has occurred
      state = find_conflict_state(current, states)

      debug { "    -> Going to: #{current.name} state" } if current

      # Resolve the conflicts by rewinding the state
      # when the conflicted gem was activated
      reqs, activated, depth = resolve_for_conflict(state)

      # Keep the state around if it still has other possibilities
      states << state unless state.possibles.empty?
      clear_search_cache

      return reqs, activated, depth
    end

    def resolve(reqs, activated)
      states = []
      depth = 0

      until reqs.empty?

        indicate_progress

        debug { print "\e[2J\e[f" ; "==== Iterating ====\n\n" }

        reqs = reqs.sort_by do |a|
          [ activated[a.name] ? 0 : 1,
            a.requirement.prerelease? ? 0 : 1,
            @errors[a.name]   ? 0 : 1,
            activated[a.name] ? 0 : @gems_size[a] ]
        end

        debug { "Activated:\n" + activated.values.map {|a| "  #{a}" }.join("\n") }
        debug { "Requirements:\n" + reqs.map {|r| "  #{r}"}.join("\n") }

        current = reqs.shift

        $stderr.puts "#{' ' * depth}#{current}" if ENV['DEBUG_RESOLVER_TREE']

        debug { "Attempting:\n  #{current}"}

        existing = activated[current.name]


        if existing || current.name == 'bundler'
          # Force the current
          if current.name == 'bundler' && !existing
            existing = search(DepProxy.new(Dependency.new('bundler', VERSION), Platform::RUBY)).first
            raise GemNotFound, %Q{Pod could not find gem "bundler" (#{VERSION})} unless existing
            existing.required_by << existing
            activated['bundler'] = existing
          end

          if current.requirement.satisfied_by?(existing.version)
            debug { "    * [SUCCESS] Already activated" }
            @errors.delete(existing.name)
            dependencies = existing.activate_platform(current.__platform)
            reqs.concat dependencies

            dependencies.each do |dep|
              next if dep.type == :development
              @gems_size[dep] ||= gems_size(dep)
            end

            depth += 1
            next
          else
            debug { "    * [FAIL] Already activated" }
            @errors[existing.name] = [existing, current]

            parent = current.required_by.last
            if existing.respond_to?(:required_by)
              parent = handle_conflict(current, states, existing.required_by[-2]) unless other_possible?(parent, states)
            else
              parent = handle_conflict(current, states) unless other_possible?(parent, states)
            end

            raise version_conflict if parent.nil? || parent.name == 'bundler'


            reqs, activated, depth = resolve_conflict(parent, states)
          end
        else
          matching_versions = search(current)

          # If we found no versions that match the current requirement
          if matching_versions.empty?
            # If this is a top-level Gemfile requirement
            if current.required_by.empty?
              if base = @base[current.name] and !base.empty?
                version = base.first.version
                message = "You have requested:\n" \
                  "  #{current.name} #{current.requirement}\n\n" \
                  "The bundle currently has #{current.name} locked at #{version}.\n" \
                  "Try running `bundle update #{current.name}`"
              elsif current.external_source
                name = current.name
                versions = @source_requirements[name][name].map { |s| s.version }
                message  = "Could not find gem '#{current}' in #{current.source}.\n"
                if versions.any?
                  message << "Source contains '#{name}' at: #{versions.join(', ')}"
                else
                  message << "Source does not contain any versions of '#{current}'"
                end
              else
                message = "Could not find gem '#{current}' "
                # if @index.source_types.include?(Source::Rubygems)
                #   message << "in any of the gem sources listed in your Gemfile."
                # else
                #   message << "in the gems available on this machine."
                # end
              end
              raise message
              # This is not a top-level Gemfile requirement
            else
              @errors[current.name] = [nil, current]
              parent = handle_conflict(current, states)
              reqs, activated, depth = resolve_conflict(parent, states)
              next
            end
          end

          state = State.new(reqs.dup, activated.dup, current, matching_versions, depth)
          states << state
          requirement = state.possibles.pop
          activate_gem(reqs, activated, requirement, current)
        end
      end
      successify(activated)
    end

    def gems_size(dep)
      search(dep).size
    end

    def clear_search_cache
      @deps_for = {}
    end

    def search(dep)
      if base = @base[dep.name] and base.any?
        reqs = [dep.requirement.as_list, base.first.version.to_s].flatten.compact
        d = Dependency.new(base.first.name, *reqs)
      else
        d = dep.dup
      end

      @deps_for[d.hash] ||= begin
        index = @source_requirements[d.name] || @index
        results = index.search(d)

        if results
          results.required_by(d, d.name)
          version = results.highest_version
          nested  = [[]]
          if results.specification.version != version
            nested << []
            version = results.specification.version
          end
          nested.last << results.specification
          deps = nested.map{|a| SpecGroup.new(a) }.select{|sg| sg.for?(Platform.new :ios) }
        else
          deps = []
        end
      end
      @deps_for[d.hash]
    end

    def clean_req(req)
      if req.to_s.include?(">= 0")
        req.to_s.gsub(/ \(.*?\)$/, '')
      else
        req.to_s.gsub(/\, (runtime|development)\)$/, ')')
      end
    end

    def version_conflict
      VersionConflict.new(errors.keys, error_message)
    end

    # For a given conflicted requirement, print out what exactly went wrong
    def gem_message(requirement, required_by=[])
      m = ""

      # A requirement that is required by itself is actually in the Gemfile, and does
      # not "depend on" itself
      if requirement.required_by.first && requirement.required_by.first.name != requirement.name
        dependency_tree(m, required_by)
        m << "#{clean_req(requirement)}\n"
      else
        m << "    #{clean_req(requirement)}\n"
      end
      m << "\n"
    end

    def dependency_tree(m, requirements)
      requirements.each_with_index do |i, j|
        m << "    " << ("  " * j)
        m << "#{clean_req(i)}"
        m << " depends on\n"
      end
      m << "    " << ("  " * requirements.size)
    end

    def error_message
      errors.inject("") do |o, (conflict, (origin, requirement))|

        # origin is the SpecSet of specs from the Gemfile that is conflicted with
        if origin

          o << %{Pod could not find compatible versions for gem "#{origin.name}":\n}
          o << "  In Gemfile:\n"

          required_by = requirement.required_by
          o << gem_message(requirement, required_by)

          # If the origin is "bundler", the conflict is us
          if origin.name == "bundler"
            o << "  Current Pod version:\n"
            other_bundler_required = !requirement.requirement.satisfied_by?(origin.version)
          # If the origin is a LockfileParser, it does not respond_to :required_by
          elsif !origin.respond_to?(:required_by) || !(origin.required_by.first)
            o << "  In snapshot (Gemfile.lock):\n"
          end

          required_by = origin.required_by[0..-2]
          o << gem_message(origin, required_by)

          # If the bundle wants a newer bundler than the running bundler, explain
          if origin.name == "bundler" && other_bundler_required
            o << "This Gemfile requires a different version of Pod.\n"
            o << "Perhaps you need to update Pod by running `gem install bundler`?"
          end

        # origin is nil if the required gem and version cannot be found in any of
        # the specified sources
        else

          # if the gem cannot be found because of a version conflict between lockfile and gemfile,
          # print a useful error that suggests running `bundle update`, which may fix things
          #
          # @base is a SpecSet of the gems in the lockfile
          # conflict is the name of the gem that could not be found
          if locked = @base[conflict].first
            o << "Pod could not find compatible versions for gem #{conflict.inspect}:\n"
            o << "  In snapshot (Gemfile.lock):\n"
            o << "    #{clean_req(locked)}\n\n"

            o << "  In Gemfile:\n"

            required_by = requirement.required_by
            o << gem_message(requirement, required_by)
            o << "Running `bundle update` will rebuild your snapshot from scratch, using only\n"
            o << "the gems in your Gemfile, which may resolve the conflict.\n"

          # the rest of the time, the gem cannot be found because it does not exist in the known sources
          else
            if requirement.required_by.first
              o << "Could not find gem '#{clean_req(requirement)}', which is required by "
              o << "gem '#{clean_req(requirement.required_by.first)}', in any of the sources."
            else
              o << "Could not find gem '#{clean_req(requirement)} in any of the sources\n"
            end
          end

        end
        o
      end
    end

    private

    # Indicates progress by writing a '.' every iteration_rate time which is
    # approximately every second. iteration_rate is calculated in the first
    # second of resolve running.
    def indicate_progress
      @iteration_counter += 1

      if iteration_rate.nil?
        if ((Time.now - started_at) % 3600).round >= 1
          @iteration_rate = iteration_counter
        end
      else
        if ((iteration_counter % iteration_rate) == 0)
          UI.message "."
        end
      end
    end
  end
end
