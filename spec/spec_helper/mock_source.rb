class MockSource < Pod::Source
  attr_reader :name

  def initialize(name, &blk)
    @name = name
    @_pods_by_name = Hash.new { |h, k| h[k] = [] }
    @_current_pod = nil
    instance_eval(&blk)
    super('/mock/repo')
  end

  def pod(name, version = '1.0', platform: [[:ios, '9.0'], [:macos, '10.12']], test_spec: false, app_spec: false, &_blk)
    cp = @_current_pod
    Pod::Specification.new(cp, name, test_spec, :app_specification => app_spec) do |spec|
      @_current_pod = spec
      if cp
        cp.subspecs << spec
      else
        spec.version = version
      end
      platform.each { |pl, dt| spec.send(pl).deployment_target = dt }
      yield spec if block_given?
    end
    @_pods_by_name[name] << @_current_pod if cp.nil?
  ensure
    @_current_pod = cp
  end

  def test_spec(name: 'Tests', &blk)
    pod(name, :test_spec => true, &blk)
  end

  def app_spec(name: 'App', &blk)
    pod(name, :app_spec => true, &blk)
  end

  def all_specs
    @_pods_by_name.values.flatten(1)
  end

  def pods
    @_pods_by_name.keys
  end

  def search(query)
    query = query.root_name if query.is_a?(Pod::Dependency)
    set(query) if @_pods_by_name.key?(query)
  end

  def specification(name, version)
    @_pods_by_name[name].find { |s| s.version == Pod::Version.new(version) }
  end

  def versions(name)
    @_pods_by_name[name].map(&:version)
  end

  def specification_path(name, version)
    pod_path(name).join(version.to_s, "#{name}.podspec")
  end

  def specs_dir
    repo
  end
end
