framework 'Foundation'
require 'fileutils'

module Pod
  module Xcode
    class Project
      class PBXObject
        def self.attributes_accessor(*names)
          names.each do |name|
            name = name.to_s
            define_method(name) { @attributes[name] }
            define_method("#{name}=") { |value| @attributes[name] = value }
          end
        end

        def self.isa
          @isa ||= name.split('::').last
        end

        attr_reader :uuid, :attributes
        attributes_accessor :isa, :name

        def initialize(project, uuid, attributes)
          @project, @uuid, @attributes = project, uuid || generate_uuid, attributes
          self.isa ||= self.class.isa
        end

        def inspect
          "#<#{isa} UUID: `#{uuid}', name: `#{name}'>"
        end

        private

        def generate_uuid
          _uuid = CFUUIDCreate(nil)
          uuid = CFUUIDCreateString(nil, _uuid)
          CFRelease(_uuid)
          CFMakeCollectable(uuid)
          # Xcode's version is actually shorter, not worrying about collisions too much right now.
          uuid.gsub('-', '')[0..23]
        end

        def list_by_class(uuids, klass, scoped = nil)
          unless scoped
            scoped = uuids.map { |uuid| @project.objects[uuid] }.select { |o| o.is_a?(klass) }
          end
          PBXObjectList.new(klass, @project, scoped) do |object|
            # Add the uuid of a newly created object to the uuids list
            uuids << object.uuid
          end
        end
      end

      class PBXGroup < PBXObject
        attributes_accessor :sourceTree, :children

        def initialize(project, uuid, attributes)
          super
          self.sourceTree ||= '<group>'
          self.children ||= []
        end

        def files
          list_by_class(children, PBXFileReference)
        end

        def source_files
          list_by_class(children, PBXFileReference, files.select { |file| !file.build_file.nil? })
        end

        def groups
          list_by_class(children, PBXGroup)
        end

        def add_source_file(path, copy_header_phase = nil, compiler_flags = nil)
          file = files.new('path' => path.to_s)
          build_file = file.build_file
          if path.extname == '.h'
            build_file.settings = { 'ATTRIBUTES' => ["Public"] }
            # Working around a bug in Xcode 4.2 betas, remove this once the Xcode bug is fixed:
            # https://github.com/alloy/cocoapods/issues/13
            #phase = copy_header_phase || @project.headers_build_phases.first
            phase = copy_header_phase || @project.copy_files_build_phases.first # TODO is this really needed?
            phase.files << build_file
          else
            build_file.settings = { 'COMPILER_FLAGS' => compiler_flags } if compiler_flags
            @project.source_build_phase.files << build_file
          end
          file
        end
        
        def <<(child)
          children << child.uuid
        end
      end

      class PBXFileReference < PBXObject
        attributes_accessor :path, :sourceTree

        def initialize(project, uuid, attributes)
          is_new = uuid.nil?
          super
          self.name ||= pathname.basename.to_s
          self.sourceTree ||= 'SOURCE_ROOT'
          if is_new
            @project.build_files.new.file = self
          end
        end

        def pathname
          Pathname.new(path)
        end

        def build_file
          @project.build_files.find { |o| o.fileRef == uuid }
        end
      end

      class PBXBuildFile < PBXObject
        attributes_accessor :fileRef, :settings

        # Takes a PBXFileReference instance and assigns its uuid to the fileRef attribute.
        def file=(file)
          self.fileRef = file.uuid
        end

        # Returns a PBXFileReference instance corresponding to the uuid in the fileRef attribute.
        def file
          @project.objects[fileRef]
        end
      end

      class PBXBuildPhase < PBXObject
        attributes_accessor :files
        alias_method :file_uuids, :files
        alias_method :file_uuids=, :files=

        def initialize(project, uuid, attributes)
          super
          self.file_uuids ||= []
        end

        def files
          list_by_class(file_uuids, PBXBuildFile)
        end
      end
      class PBXSourcesBuildPhase < PBXBuildPhase;    end
      class PBXCopyFilesBuildPhase < PBXBuildPhase;  end
      class PBXFrameworksBuildPhase < PBXBuildPhase; end

      class PBXNativeTarget < PBXObject
        attributes_accessor :buildPhases, :buildConfigurationList
        alias_method :build_phase_uuids, :buildPhases
        alias_method :build_phase_uuids=, :buildPhases=
        alias_method :build_configuration_list_uuid, :buildConfigurationList
        alias_method :build_configuration_list_uuid=, :buildConfigurationList=

        def buildPhases
          list_by_class(build_phase_uuids, PBXBuildPhase)
        end
        
        def buildConfigurationList
          @project.objects[build_configuration_list_uuid]
        end
        
        def buildConfigurationList=(config_list)
          self.build_configuration_list_uuid = config_list.uuid
        end
      end

      class XCBuildConfiguration < PBXObject
        attributes_accessor :baseConfigurationReference
        alias_method :base_configuration_reference_uuid, :baseConfigurationReference
        alias_method :base_configuration_reference_uuid=, :baseConfigurationReference=
        
        def baseConfigurationReference
          @project.objects[base_configuration_reference_uuid]
        end
        
        def baseConfigurationReference=(config)
          self.base_configuration_reference_uuid = config.uuid
        end
      end
      
      class XCConfigurationList < PBXObject
        attributes_accessor :buildConfigurations
        alias_method :build_configuration_uuids, :buildConfigurations
        alias_method :build_configuration_uuids=, :buildConfigurations=
        
        def buildConfigurations
          list_by_class(build_configuration_uuids, XCBuildConfiguration)
        end
        
        def buildConfigurations=(configs)
          self.build_configuration_uuids = configs.map(&:uuid)
        end
      end

      # Missing constants that begin with either `PBX' or `XC' are assumed to be
      # valid classes in a Xcode project. A new PBXObject subclass is created
      # for the constant and returned.
      def self.const_missing(name)
        if name =~ /^(PBX|XC)/
          klass = Class.new(PBXObject)
          const_set(name, klass)
          klass
        else
          super
        end
      end

      class PBXObjectList
        include Enumerable

        def initialize(represented_class, project, scoped, &new_object_callback)
          @represented_class = represented_class
          @project           = project
          @scoped_hash       = scoped.is_a?(Array) ? scoped.inject({}) { |h, o| h[o.uuid] = o.attributes; h } : scoped
          @callback          = new_object_callback
        end

        def [](uuid)
          if hash = @scoped_hash[uuid]
            Project.const_get(hash['isa']).new(@project, uuid, hash)
          end
        end

        def add(klass, hash = {})
          object = klass.new(@project, nil, hash)
          @project.objects_hash[object.uuid] = object.attributes
          object
        end

        def new(hash = {})
          object = add(@represented_class, hash)
          @callback.call(object) if @callback
          object
        end

        def <<(object)
          @callback.call(object) if @callback
        end

        def each
          @scoped_hash.keys.each do |uuid|
            yield self[uuid]
          end
        end

        def inspect
          "<PBXObjectList: #{map(&:inspect)}>"
        end

        # Only makes sense on the list that has the full objects_hash as its scoped hash.
        def select_by_class(klass)
          scoped = @project.objects_hash.select { |_, attr| attr['isa'] == klass.isa }
          PBXObjectList.new(klass, @project, scoped)
        end
      end

      def initialize(xcodeproj)
        file = File.join(xcodeproj, 'project.pbxproj')
        @plist = NSMutableDictionary.dictionaryWithContentsOfFile(file.to_s)
      end

      def to_hash
        @plist
      end

      def objects_hash
        @plist['objects']
      end

      def objects
        @objects ||= PBXObjectList.new(PBXObject, self, objects_hash)
      end

      def groups
        objects.select_by_class(PBXGroup)
      end
      
      def main_group
        project = objects[@plist['rootObject']]
        objects[project.attributes['mainGroup']]
      end

      # Shortcut access to the `Pods' PBXGroup.
      def pods
        groups.find { |g| g.name == 'Pods' }
      end

      # Adds a group as child to the `Pods' group.
      def add_pod_group(name)
        pods.groups.new('name' => name)
      end

      def files
        objects.select_by_class(PBXFileReference)
      end

      def build_files
        objects.select_by_class(PBXBuildFile)
      end

      def source_build_phase
        objects.find { |o| o.is_a?(PBXSourcesBuildPhase) }
      end

      def copy_files_build_phases
        objects.select_by_class(PBXCopyFilesBuildPhase)
      end

      def targets
        objects.select_by_class(PBXNativeTarget)
      end

      IGNORE_GROUPS = ['Pods', 'Frameworks', 'Products', 'Supporting Files']
      def source_files
        source_files = {}
        groups.each do |group|
          next if group.name.nil? || IGNORE_GROUPS.include?(group.name)
          source_files[group.name] = group.source_files.map(&:pathname)
        end
        source_files
      end

      def save_as(projpath)
        projpath = projpath.to_s
        FileUtils.mkdir_p(projpath)
        @plist.writeToFile(File.join(projpath, 'project.pbxproj'), atomically:true)
      end

      # TODO add comments, or even constants, describing what these magic numbers are.
      def add_copy_header_build_phase(name, path)
        phase = copy_files_build_phases.new({
           "buildActionMask" => "2147483647",
           "dstPath" => "$(PUBLIC_HEADERS_FOLDER_PATH)/#{path}",
           "dstSubfolderSpec" => "16",
           "name" => "Copy #{name} Public Headers",
           "runOnlyForDeploymentPostprocessing" => "0",
        })
        targets.first.buildPhases << phase
        phase
      end

      # A silly hack to pretty print the objects hash from MacRuby.
      def pretty_print
        puts `ruby -r pp -e 'pp(#{@template.inspect})'`
      end
    end
  end
end
