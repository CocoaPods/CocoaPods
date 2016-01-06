module Pod
  class Installer
    # Context object designed to be used with the HooksManager which describes
    # the context of the installer before analysis has been completed.
    #
    class PreInstallHooksContext
      # @return [String] The path to the sandbox root (`Pods` directory).
      #
      attr_accessor :sandbox_root

      # @return [Podfile] The Podfile for the project.
      #
      attr_accessor :podfile

      # @return [Sandbox] The Sandbox for the project.
      #
      attr_accessor :sandbox

      # @return [Lockfile] The Lockfile for the project.
      #
      attr_accessor :lockfile

      # @param  [Sandbox] sandbox see {#sandbox}
      #
      # @param  [Podfile] podfile see {#podfile}
      #
      # @param  [Lockfile] lockfile see {#lockfile}
      #
      # @return [PreInstallHooksContext] Convenience class method to generate the
      #         static context.
      #
      def self.generate(sandbox, podfile, lockfile)
        result = new
        result.podfile = podfile
        result.sandbox = sandbox
        result.sandbox_root = sandbox.root.to_s
        result.lockfile = lockfile
        result
      end
    end
  end
end
