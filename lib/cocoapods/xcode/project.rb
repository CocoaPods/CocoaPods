framework 'Foundation'

module Pod
  module Xcode
    class Project
      include Pod::Config::Mixin

      # TODO this is a workaround for an issue with MacRuby with compiled files
      # that makes the use of __FILE__ impossible.
      #
      #TEMPLATES_DIR = Pathname.new(File.expand_path('../../../../xcode-project-templates', __FILE__))
      file = $LOADED_FEATURES.find { |file| file =~ %r{cocoapods/xcode/project\.rbo?$} }
      TEMPLATES_DIR = Pathname.new(File.expand_path('../../../../xcode-project-templates', file))

      # TODO see if we really need different templates for iOS and OS X
      def self.ios_static_library
        new TEMPLATES_DIR + 'cocoa-touch-static-library'
      end

      def initialize(template_dir)
        @template_dir = template_dir
        file = template_dir + template_file
        @template = NSMutableDictionary.dictionaryWithContentsOfFile(file.to_s)
      end

      def template_file
        'Pods.xcodeproj/project.pbxproj'
      end

      def to_hash
        @template
      end

      def find_objects(conditions)
        objects.select do |_, object|
          object.objectsForKeys(conditions.keys, notFoundMarker:Object.new) == conditions.values
        end
      end

      def find_object(conditions)
        find_objects(conditions).first
      end

      IGNORE_GROUPS = ['Pods', 'Frameworks', 'Products', 'Supporting Files']
      def source_files
        source_files = {}
        find_objects('isa' => 'PBXGroup').each do |_, object|
          next if object['name'].nil? || IGNORE_GROUPS.include?(object['name'])
          source_files[object['name']] = object['children'].map do |uuid|
            Pathname.new(objects[uuid]['path'])
          end
        end
        source_files
      end

      def add_source_file(file, group, phase_uuid = nil, compiler_flags = nil)
        file_ref_uuid = add_file_reference(file, 'SOURCE_ROOT')
        add_object_to_group(file_ref_uuid, group)
        if file.extname == '.h'
          build_file_uuid = add_build_file(file_ref_uuid, "settings" => { "ATTRIBUTES" => ["Public"] })
          # Working around a bug in Xcode 4.2 betas, remove this once the Xcode bug is fixed:
          # https://github.com/alloy/cocoapods/issues/13
          #add_file_to_list('PBXHeadersBuildPhase', build_file_uuid)
          add_file_to_list('PBXCopyFilesBuildPhase', build_file_uuid, phase_uuid)
        else
          extra = compiler_flags ? {"settings" => { "COMPILER_FLAGS" => compiler_flags }} : {}
          build_file_uuid = add_build_file(file_ref_uuid, extra)
          add_file_to_list('PBXSourcesBuildPhase', build_file_uuid)
        end
        file_ref_uuid
      end
      
      def add_group(name)
        group_uuid = add_object({
          "name" => name,
          "isa" => "PBXGroup",
          "sourceTree" => "<group>",
          "children" => []
        })
        add_object_to_group(group_uuid, 'Pods')
        group_uuid
      end

      def create_in(pods_root)
        puts "  * Copying contents of template directory `#{@template_dir}' to `#{pods_root}'" if config.verbose?
        FileUtils.cp_r("#{@template_dir}/.", pods_root)
        pbxproj = pods_root + template_file
        puts "  * Writing Xcode project file to `#{pbxproj}'" if config.verbose?
        @template.writeToFile(pbxproj.to_s, atomically:true)
      end

      # TODO add comments, or even constants, describing what these magic numbers are.
      def add_copy_header_build_phase(name, path)
        phase_uuid = add_object({
           "isa" => "PBXCopyFilesBuildPhase",
           "buildActionMask" => "2147483647",
           "dstPath" => "$(PUBLIC_HEADERS_FOLDER_PATH)/#{path}",
           "dstSubfolderSpec" => "16",
           "files" => [],
           "name" => "Copy #{name} Public Headers",
           "runOnlyForDeploymentPostprocessing" => "0",
        })
        
        object_uuid, object = objects_by_isa('PBXNativeTarget').first
        object['buildPhases'] << phase_uuid
        phase_uuid
      end

      def objects_by_isa(isa)
        objects.select { |_, object| object['isa'] == isa }
      end

      private

      def add_object(object)
        uuid = generate_uuid
        objects[uuid] = object
        uuid
      end

      def add_file_reference(path, source_tree)
        add_object({
          "name" => path.basename.to_s,
          "isa" => "PBXFileReference",
          "sourceTree" => source_tree,
          "path" => path.to_s,
        })
      end
      
      def add_build_file(file_ref_uuid, extra = {})
        add_object(extra.merge({
          "isa" => "PBXBuildFile",
          "fileRef" => file_ref_uuid
        }))
      end
      
      # TODO refactor to create PBX object classes and make this take aither a uuid or a class instead of both.
      def add_file_to_list(isa, build_file_uuid, phase_uuid = nil)
        objects = objects_by_isa(isa)
        _ = object = nil
        if phase_uuid.nil?
          _, object = objects.first
        else
          object = objects[phase_uuid]
        end
        object['files'] << build_file_uuid
      end

      def add_object_to_group(object_ref_uuid, name)
        object_uuid, object = objects.find do |_, object|
          object['isa'] == 'PBXGroup' && object['name'] == name
        end
        object['children'] << object_ref_uuid
      end

      def objects
        @template['objects']
      end

      def generate_uuid
        _uuid = CFUUIDCreate(nil)
        uuid = CFUUIDCreateString(nil, _uuid)
        CFRelease(_uuid)
        CFMakeCollectable(uuid)
        # Xcode's version is actually shorter, not worrying about collisions too much right now.
        uuid.gsub('-', '')[0..23]
      end

      public

      def pretty_print
        puts `ruby -r pp -e 'pp(#{@template.inspect})'`
      end
    end
  end
end
