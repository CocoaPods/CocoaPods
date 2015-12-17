module Pod
  # Metadata about an installed Xcode simulator
  class Simulator
    attr_reader :id
    attr_reader :name
    attr_reader :os_name
    attr_reader :os_version

    def self.match(line, os_name, os_version)
      sims = []
      @sim_regex.match(line) { |m| sims << Simulator.new(m, os_name, os_version) }
      sims
    end

    def to_s
      "#{@name} (#{@id}) - #{@os_name} #{@os_version}"
    end

    private

    @sim_regex = /^\s*(?<sim_name>[^\)]*?) \((?<sim_id>[^\)]*?)\) \((?<sim_state>[^\)]*?)\)$/

    def initialize(match_data, os_name, os_version)
      @id = match_data['sim_id']
      @name = match_data['sim_name']
      @os_name = os_name
      @os_version = os_version
    end
  end

  # Executes `simctl` commands
  class SimControl
    extend Executable
    executable :xcrun

    def initialize
      @os_regex = /^-- (?<os_name>.*?) (?<os_version>[0-9].[0-9]) --$/
    end

    def destination(filter)
      sim = simulator(filter)
      raise "Simulator #{filter} is not available." if sim.nil?
      ['-destination', "id=#{sim.id}"]
    end

    def simulator(filter)
      usable_simulators(filter).first
    end

    def usable_simulators(filter = nil)
      os_name = ''
      os_version = ''
      sims = []

      list(['devices']).lines.each do |line|
        @os_regex.match(line) do |m|
          os_name = m['os_name']
          os_version = m['os_version']
        end
        sims += Simulator.match(line, os_name, os_version)
      end

      return sims if filter.nil?
      sims.select { |sim| sim.name == filter }
    end

    private

    def list(args)
      simctl!(['list'] + args)
    end

    def simctl!(args)
      xcrun!(['simctl'] + args)
    end
  end
end
