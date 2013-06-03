module Pod
  class Installer

    # Migrates installations performed by previous versions of CocoaPods.
    #
    class Migrator

      #
      #
      attr_reader :installation_version

      #
      #
      attr_reader :sandbox

      #
      #
      def initialize(sandbox)
        @sandbox = sandbox
      end

      #
      #
      def migrate!
        if sandbox.manifest
          migrate_to_0_20 if version_minor('0.20')
        end
      end

      #-----------------------------------------------------------------------#

      private

      # @!group Migration Steps

      def migrate_to_0_20
        title_options = { :verbose_prefix => "-> ".green }
        UI.titled_section("Migrating to CocoaPods 0.20".green, title_options) do
          mkdir(sandbox.generated_dir_root)
          mkdir(sandbox.headers_root)
          mkdir(sandbox.sources_root)
           sandbox.root.children.each do |child|
            relative = child.relative_path_from(sandbox.root)
            case relative.to_s
            when 'Generated'
              next
            when 'BuildHeaders', 'Headers'
              move(child, sandbox.headers_root + relative)
            else
              if child.directory? && child.extname != '.xcodeproj'
                move(child, sandbox.sources_root + relative)
              else
                move(child, sandbox.generated_dir_root + relative)
              end
            end
          end
        end
      end


      #-----------------------------------------------------------------------#

      private

      # @!group Private helpers

      def version_minor(target_version)
        installation_version < Version.new(target_version)
      end

      def installation_version
        sandbox.manifest.cocoapods_version
      end

      def mkdir(path)
        path.mkpath
      end

      def move(path, new_name)
        path.rename(new_name)
      end

      #-----------------------------------------------------------------------#

    end
  end
end
