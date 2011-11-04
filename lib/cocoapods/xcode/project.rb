framework 'Foundation'
require 'fileutils'

module Pod
  module Xcode
    class Project
      class PBXObject
        def self.attribute(attribute_name, accessor_name = nil)
          attribute_name = attribute_name.to_s
          name = (accessor_name || attribute_name).to_s
          define_method(name) { @attributes[attribute_name] }
          define_method("#{name}=") { |value| @attributes[attribute_name] = value }
        end

        def self.attributes(*names)
          names.each { |name| attribute(name) }
        end

        def self.has_many(plural_attr_name, options = {}, &block)
          klass = options[:class] || PBXFileReference
          singular_attr_name = options[:singular] || plural_attr_name.to_s[0..-2] # strip off 's'
          if options[:fkey_on_target]
            define_method(plural_attr_name) do
              scoped = @project.objects.select_by_class(klass).select do |object|
                object.send(options[:uuid]) == self.uuid
              end
              PBXObjectList.new(klass, @project, scoped) do |object|
                object.send("#{options[:uuid]}=", self.uuid)
              end
            end
          else
            uuid_list_name = options[:uuid] || "#{singular_attr_name}References"
            attribute(plural_attr_name, uuid_list_name)
            define_method(plural_attr_name) do
              uuids = send(uuid_list_name)
              if block
                list_by_class(uuids, klass) do |object|
                  instance_exec(object, &block)
                end
              else
                list_by_class(uuids, klass)
              end
            end
            define_method("#{plural_attr_name}=") do |objects|
              send("#{uuid_list_name}=", objects.map(&:uuid))
            end
          end
        end

        def self.belongs_to(singular_attr_name, options = {})
          uuid_name = options[:uuid] || "#{singular_attr_name}Reference"
          attribute(options[:uuid] || singular_attr_name, uuid_name)
          define_method(singular_attr_name) do
            uuid = send(uuid_name)
            @project.objects[uuid]
          end
          define_method("#{singular_attr_name}=") do |object|
            send("#{uuid_name}=", object.uuid)
          end
        end

        def self.has_one(singular_attr_name, options = {})
          klass = options[:class]
          uuid_name = options[:uuid] || "#{singular_attr_name}Reference"
          define_method(singular_attr_name) do
            @project.objects.select_by_class(klass).find do |object|
              object.respond_to?(uuid_name) && object.send(uuid_name) == self.uuid
            end
          end
        end

        def self.isa
          @isa ||= name.split('::').last
        end

        attr_reader :uuid, :attributes
        attributes :isa, :name

        def initialize(project, uuid, attributes)
          @project, @attributes = project, attributes
          unless uuid
            # Add new objects to the main hash with a unique UUID
            begin; uuid = generate_uuid; end while @project.objects_hash.has_key?(uuid)
            @project.objects_hash[uuid] = @attributes
          end
          @uuid = uuid
          self.isa ||= self.class.isa
        end

        def ==(other)
          other.is_a?(PBXObject) && self.uuid == other.uuid
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

        def list_by_class(uuids, klass, scoped = nil, &block)
          unless scoped
            scoped = uuids.map { |uuid| @project.objects[uuid] }.select { |o| o.is_a?(klass) }
          end
          if block
            PBXObjectList.new(klass, @project, scoped, &block)
          else
            PBXObjectList.new(klass, @project, scoped) do |object|
              # Add the uuid of a newly created object to the uuids list
              uuids << object.uuid
            end
          end
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

      class PBXFileReference < PBXObject
        attributes :path, :sourceTree, :explicitFileType, :includeInIndex
        has_many :buildFiles, :uuid => :fileRef, :fkey_on_target => true, :class => Project::PBXBuildFile

        def initialize(project, uuid, attributes)
          is_new = uuid.nil?
          super
          self.path = path if path # sets default name
          self.sourceTree ||= 'SOURCE_ROOT'
          if is_new
            @project.main_group.children << self
          end
        end

        alias_method :_path=, :path=
        def path=(path)
          self._path = path
          self.name ||= pathname.basename.to_s
          path
        end

        def pathname
          Pathname.new(path)
        end
      end

      class PBXGroup < PBXObject
        attributes :sourceTree

        has_many :children, :singular => :child do |object|
          if object.is_a?(PBXFileReference)
            # Remove from the group it was in
            if group = @project.groups.find { |group| group.children.include?(object) }
              # TODO
              # * group.children.delete(object)
              # * object.group = nil
              group.childReferences.delete(object.uuid)
            end
          end
          childReferences << object.uuid
        end

        def initialize(*)
          super
          self.sourceTree ||= '<group>'
          self.childReferences ||= []
        end

        def files
          list_by_class(childReferences, PBXFileReference)
        end

        def source_files
          list_by_class(childReferences, PBXFileReference, files.reject { |file| file.buildFiles.empty? })
        end

        def groups
          list_by_class(childReferences, PBXGroup)
        end

        def <<(child)
          children << child
        end
      end

      class PBXBuildFile < PBXObject
        attributes :settings
        belongs_to :file, :uuid => :fileRef
      end

      class PBXBuildPhase < PBXObject
        # TODO rename this to buildFiles and add a files :through => :buildFiles shortcut
        has_many :files, :class => PBXBuildFile

        attributes :buildActionMask, :runOnlyForDeploymentPostprocessing

        def initialize(*)
          super
          self.fileReferences ||= []
          # These are always the same, no idea what they are.
          self.buildActionMask ||= "2147483647"
          self.runOnlyForDeploymentPostprocessing ||= "0"
        end
      end

      class PBXCopyFilesBuildPhase < PBXBuildPhase
        attributes :dstPath, :dstSubfolderSpec

        def self.new_pod_dir(project, pod_name, path)
          new(project, nil, {
            "dstPath" => "$(PUBLIC_HEADERS_FOLDER_PATH)/#{path}",
            "name"    => "Copy #{pod_name} Public Headers",
          })
        end

        def initialize(*)
          super
          self.dstSubfolderSpec ||= "16"
        end
      end

      class PBXSourcesBuildPhase < PBXBuildPhase;     end
      class PBXFrameworksBuildPhase < PBXBuildPhase;  end
      class PBXShellScriptBuildPhase < PBXBuildPhase
        attribute :shellScript
      end

      class PBXNativeTarget < PBXObject
        STATIC_LIBRARY = 'com.apple.product-type.library.static'

        attributes :productName, :productType

        has_many :buildPhases, :class => PBXBuildPhase
        has_many :dependencies, :singular => :dependency # TODO :class => ?
        has_many :buildRules # TODO :class => ?
        belongs_to :buildConfigurationList
        belongs_to :product, :uuid => :productReference

        def self.new_static_library(project, productName)
          # TODO should probably switch the uuid and attributes argument
          target = new(project, nil, 'productType' => STATIC_LIBRARY, 'productName' => productName)
          target.product.path = "lib#{productName}.a"
          target.product.includeInIndex = "0" # no idea what this is
          target.product.explicitFileType = "archive.ar"
          target.buildPhases.add(PBXSourcesBuildPhase)

          buildPhase = target.buildPhases.add(PBXFrameworksBuildPhase)
          project.groups.find { |g| g.name == 'Frameworks' }.files.each do |framework|
            buildPhase.files << framework.buildFiles.new
          end

          target.buildPhases.add(PBXCopyFilesBuildPhase, 'dstPath' => '$(PUBLIC_HEADERS_FOLDER_PATH)')
          target
        end

        def initialize(project, *)
          super
          self.name ||= productName
          self.buildRuleReferences  ||= []
          self.dependencyReferences ||= []

          unless buildConfigurationList
            self.buildConfigurationList = project.objects.add(XCConfigurationList)
            # TODO or should this happen in buildConfigurationList?
            buildConfigurationList.buildConfigurations.new('name' => 'Debug')
            buildConfigurationList.buildConfigurations.new('name' => 'Release')
          end

          self.product ||= project.files.new('sourceTree' => 'BUILT_PRODUCTS_DIR')
          self.buildPhaseReferences ||= []
        end

        def buildConfigurations
          buildConfigurationList.buildConfigurations
        end

        def source_build_phases
          buildPhases.select_by_class(PBXSourcesBuildPhase)
        end

        def copy_files_build_phases
          buildPhases.select_by_class(PBXCopyFilesBuildPhase)
        end

        def frameworks_build_phases
          buildPhases.select_by_class(PBXFrameworksBuildPhase)
        end

        # Finds an existing file reference or creates a new one.
        def add_source_file(path, copy_header_phase = nil, compiler_flags = nil)
          file = @project.files.find { |file| file.path == path.to_s } || @project.files.new('path' => path.to_s)
          buildFile = file.buildFiles.new
          if path.extname == '.h'
            buildFile.settings = { 'ATTRIBUTES' => ["Public"] }
            # Working around a bug in Xcode 4.2 betas, remove this once the Xcode bug is fixed:
            # https://github.com/alloy/cocoapods/issues/13
            #phase = copy_header_phase || headers_build_phases.first
            phase = copy_header_phase || copy_files_build_phases.first
            phase.files << buildFile
          else
            buildFile.settings = { 'COMPILER_FLAGS' => compiler_flags } if compiler_flags
            source_build_phases.first.files << buildFile
          end
          file
        end
      end

      class XCBuildConfiguration < PBXObject
        attribute :buildSettings
        belongs_to :baseConfiguration, :uuid => :baseConfigurationReference

        def initialize(*)
          super
          # TODO These are from an iOS static library, need to check if it works for any product type
          self.buildSettings = {
            'DSTROOT'                      => '/tmp/Pods.dst',
            'GCC_PRECOMPILE_PREFIX_HEADER' => 'YES',
            'GCC_VERSION'                  => 'com.apple.compilers.llvm.clang.1_0',
            # The OTHER_LDFLAGS option *has* to be overriden so that it does not
            # use those from the xcconfig (for CocoaPods specifically).
            'OTHER_LDFLAGS'                => '',
            'PRODUCT_NAME'                 => '$(TARGET_NAME)',
            'SKIP_INSTALL'                 => 'YES',
          }.merge(buildSettings || {})
        end
      end

      class XCConfigurationList < PBXObject
        has_many :buildConfigurations, :class => XCBuildConfiguration

        def initialize(*)
          super
          self.buildConfigurationReferences ||= []
        end
      end

      class PBXProject < PBXObject
        has_many :targets, :class => PBXNativeTarget
      end

      class PBXObjectList
        include Enumerable

        def initialize(represented_class, project, scoped, &new_object_callback)
          @represented_class = represented_class
          @project           = project
          @scoped_hash       = scoped.is_a?(Array) ? scoped.inject({}) { |h, o| h[o.uuid] = o.attributes; h } : scoped
          @callback          = new_object_callback
        end

        def empty?
          @scoped_hash.empty?
        end

        def [](uuid)
          if hash = @scoped_hash[uuid]
            Project.const_get(hash['isa']).new(@project, uuid, hash)
          end
        end

        def add(klass, hash = {})
          object = klass.new(@project, nil, hash)
          @callback.call(object) if @callback
          object
        end

        def new(hash = {})
          add(@represented_class, hash)
        end

        def <<(object)
          @callback.call(object) if @callback
        end

        def each
          @scoped_hash.keys.each do |uuid|
            yield self[uuid]
          end
        end

        def ==(other)
          self.to_a == other.to_a
        end

        def first
          to_a.first
        end

        def last
          to_a.last
        end

        def inspect
          "<PBXObjectList: #{map(&:inspect)}>"
        end

        # Only makes sense on lists that contain mixed classes.
        def select_by_class(klass)
          scoped = @scoped_hash.select { |_, attr| attr['isa'] == klass.isa }
          PBXObjectList.new(klass, @project, scoped) do |object|
            # Objects added to the subselection should still use the same
            # callback as this list.
            self << object
          end
        end

        def method_missing(name, *args, &block)
          if @represented_class.respond_to?(name)
            object = @represented_class.send(name, @project, *args)
            # The callbacks are only for PBXObject instances instantiated
            # from the class method that we forwarded the message to.
            @callback.call(object) if object.is_a?(PBXObject)
            object
          else
            super
          end
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

      # TODO This should probably be the actual Project class (PBXProject).
      def project_object
        objects[@plist['rootObject']]
      end

      def groups
        objects.select_by_class(PBXGroup)
      end
      
      def main_group
        objects[project_object.attributes['mainGroup']]
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

      def targets
        # Better to check the project object for targets to ensure they are
        # actually there so the project will work
        project_object.targets
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
    end
  end
end
