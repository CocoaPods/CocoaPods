require 'fileutils'

module Pod
  class Installer
    # Migrates installations performed by previous versions of CocoaPods.
    #
    class Migrator
      class << self
        # Performs the migration.
        #
        # @param  [Sandbox] The sandbox which should be migrated.
        #
        def migrate(sandbox)
          if sandbox.manifest
            migrate_to_0_34(sandbox) if installation_minor?('0.34', sandbox)
            migrate_to_0_36(sandbox) if installation_minor?('0.36', sandbox)
          end
        end

        # @!group Migration Steps

        # Migrates from CocoaPods versions previous to 0.34.
        #
        def migrate_to_0_34(sandbox)
          UI.message('Migrating to CocoaPods 0.34') do
            delete(sandbox.root + 'Headers')
            make_path(sandbox.headers_root)

            sandbox.root.children.each do |child|
              relative = child.relative_path_from(sandbox.root)
              case relative.to_s
              when 'Manifest.lock', 'Pods.xcodeproj', 'Headers',
                'Target Support Files', 'Local Podspecs'
                next
              when 'BuildHeaders', 'PublicHeaders'
                delete(child)
              else
                if child.directory? && child.extname != '.xcodeproj'
                  next
                else
                  delete(child)
                end
              end
            end
          end

          delete(Pathname(File.join(ENV['HOME'], 'Library/Caches/CocoaPods/Git')))
        end

        # Migrates from CocoaPods versions prior to 0.36.
        #
        def migrate_to_0_36(sandbox)
          UI.message('Migrating to CocoaPods 0.36') do
            move(sandbox.root + 'Headers/Build', sandbox.root + 'Headers/Private')

            sandbox.specifications_root.children.each do |child|
              next unless child.basename.to_s =~ /\.podspec$/
              spec = Specification.from_file(child)
              child.delete
              child = Pathname("#{child}.json")
              child.write(spec.to_pretty_json)
            end
          end
        end

        # @!group Private helpers

        def installation_minor?(target_version, sandbox)
          sandbox.manifest.cocoapods_version < Version.new(target_version)
        end

        # Makes a path creating any intermediate directory and printing an UI
        # message.
        #
        # @path [#to_s] path
        #       The path.
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
