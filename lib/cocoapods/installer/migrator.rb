require 'fileutils'

module Pod
  class Installer
    # Migrates installations performed by previous versions of CocoaPods.
    #
    class Migrator
      class << self
        # Performs the migration.
        #
        # @param  [Sandbox] sandbox
        #         The sandbox which should be migrated.
        #
        def migrate(sandbox)
          return unless sandbox.manifest
        end

        # @!group Migration Steps

        # @!group Private helpers

        # Check whether a migration is required
        #
        # @param [#to_s] target_version
        #        See Version#new.
        #
        # @param [Sandbox] sandbox
        #        The sandbox
        #
        # @return [void]
        #
        def installation_minor?(target_version, sandbox)
          sandbox.manifest.cocoapods_version < Version.new(target_version)
        end

        # Makes a path creating any intermediate directory and printing an UI
        # message.
        #
        # @path [#to_s] path
        #       The path.
        #
        # @return [void]
        #
        def make_path(path)
          return if path.exist?
          UI.message "- Making path #{UI.path(path)}" do
            path.mkpath
          end
        end

        # Moves a path to another one printing an UI message.
        #
        # @path [#to_s] source
        #       The path to move.
        #
        # @path [#to_s] destination
        #       The destination path.
        #
        # @return [void]
        #
        def move(source, destination)
          return unless source.exist?
          make_path(destination.dirname)
          UI.message "- Moving #{UI.path(source)} to #{UI.path(destination)}" do
            FileUtils.mv(source.to_s, destination.to_s)
          end
        end

        # Deletes a path, including non empty directories, printing an UI
        # message.
        #
        # @path [#to_s] path
        #       The path.
        #
        # @return [void]
        #
        def delete(path)
          return unless path.exist?
          UI.message "- Deleting #{UI.path(path)}" do
            FileUtils.rm_rf(path)
          end
        end
      end
    end
  end
end
