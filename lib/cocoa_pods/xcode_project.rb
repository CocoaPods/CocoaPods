framework 'Foundation'

module Pod
  class XcodeProject
    TEMPLATES_DIR = Pathname.new(File.expand_path('../../../xcode-project-templates', __FILE__))

    # TODO see if we really need different templates for iOS and OS X
    def self.static_library
      new TEMPLATES_DIR + 'cocoa-touch-static-library/Pods.xcodeproj/project.pbxproj'
    end

    def initialize(template)
      @template = NSMutableDictionary.dictionaryWithContentsOfFile(template.to_s)
      #pretty_print
    end

    def add_source_file(file)
      file_ref_uuid = generate_uuid
      objects[file_ref_uuid] = {
        "name" => file.basename.to_s,
        "isa" => "PBXFileReference",
        "sourceTree" => "SOURCE_ROOT",
        "path" => file.to_s,
      }
      add_file_to_files_group(file_ref_uuid)

      if file.extname == '.h'
        add_header(file, file_ref_uuid)
      else
        build_file_uuid = generate_uuid
        objects[build_file_uuid] =  {
          "isa" => "PBXBuildFile",
          "fileRef" => file_ref_uuid
        }
        add_file_to_list('PBXSourcesBuildPhase', build_file_uuid)
      end
    end

    def add_header(file, file_ref_uuid)
      build_file_uuid = generate_uuid
      objects[build_file_uuid] = {
        "isa" => "PBXBuildFile",
        "fileRef" => file_ref_uuid,
        "settings"=> { "ATTRIBUTES" => ["Public"] }
      }
      add_file_to_list('PBXHeadersBuildPhase', build_file_uuid)
    end

    def to_hash
      @template
    end

    def create_at(xcodeproj)
      xcodeproj.mkpath
      pbxproj = xcodeproj + 'project.pbxproj'
      @template.writeToFile(pbxproj.to_s, atomically:true)
    end

    private

    def add_file_to_list(isa, build_file_uuid)
      object_uuid, object = object_by_isa(isa)
      #object['files'] ||= []
      object['files'] << build_file_uuid
      objects[object_uuid] = object
    end

    def add_file_to_files_group(file_ref_uuid)
      object_uuid, object = objects.find do |_, object|
        object['isa'] == 'PBXGroup' && object['name'] == 'Files'
      end
      #object['children'] ||= []
      object['children'] << file_ref_uuid
      objects[object_uuid] = object
    end

    def objects
      @template['objects']
    end

    def object_by_isa(isa)
      objects.find { |_, object| object['isa'] == isa }
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
