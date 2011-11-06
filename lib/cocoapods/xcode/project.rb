framework 'Foundation'
require 'fileutils'

require 'active_support/inflector'
require 'active_support/core_ext/string/inflections'

module Pod
  module Xcode
    class Project
      class PBXObject
        class AssociationReflection
          def initialize(name, options)
            @name, @options = name.to_s, options
          end

          attr_reader :name, :options

          def klass
            @options[:class] ||= begin
              name = "PBX#{@name.classify}"
              name = "XC#{@name.classify}" unless Project.const_defined?(name)
              Project.const_get(name)
            end
          end

          def inverse
            klass.reflection(@options[:inverse_of])
          end

          def inverse?
            !!@options[:inverse_of]
          end

          def singular_name
            @options[:singular_name] || @name.singularize
          end

          def singular_getter
            singular_name
          end

          def singular_setter
            "#{singular_name}="
          end

          def plural_name
            @name.pluralize
          end

          def plural_getter
            plural_name
          end

          def plural_setter
            "#{plural_name}="
          end

          def uuid_attribute
            @options[:uuid] || @name
          end

          def uuid_method_name
            (@options[:uuid] || @options[:uuids] || "#{singular_name}Reference").to_s.singularize
          end

          def uuid_getter
            uuid_method_name
          end

          def uuid_setter
            "#{uuid_method_name}="
          end

          def uuids_method_name
            uuid_method_name.pluralize
          end

          def uuids_getter
            uuids_method_name
          end

          def uuids_setter
            "#{uuids_method_name}="
          end
        end

        def self.reflections
          @reflections ||= []
        end

        def self.create_reflection(name, options)
          (reflections << AssociationReflection.new(name, options)).last
        end

        def self.reflection(name)
          reflections.find { |r| r.name.to_s == name.to_s }
        end

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
          reflection = create_reflection(plural_attr_name, options)
          if reflection.inverse?
            define_method(reflection.name) do
              scoped = @project.objects.select_by_class(reflection.klass).select do |object|
                object.send(reflection.inverse.uuid_getter) == self.uuid
              end
              PBXObjectList.new(reflection.klass, @project, scoped) do |object|
                object.send(reflection.inverse.uuid_setter, self.uuid)
              end
            end
          else
            attribute(reflection.name, reflection.uuids_getter)
            define_method(reflection.name) do
              uuids = send(reflection.uuids_getter)
              if block
                # Evaluate the block, which was specified at the class level, in
                # the instance’s context.
                list_by_class(uuids, reflection.klass) do |object|
                  instance_exec(object, &block)
                end
              else
                list_by_class(uuids, reflection.klass)
              end
            end
            define_method(reflection.plural_setter) do |objects|
              send(reflection.uuids_setter, objects.map(&:uuid))
            end
          end
        end

        def self.has_one(singular_attr_name, options = {})
          reflection = create_reflection(singular_attr_name, options)
          if reflection.inverse?
            define_method(reflection.name) do
              # Loop over all objects of the class and find the one that includes
              # this object in the specified uuid list.
              @project.objects.select_by_class(reflection.klass).find do |object|
                object.send(reflection.inverse.uuids_getter).include?(self.uuid)
              end
            end
            define_method(reflection.singular_setter) do |object|
              # Remove this object from the uuid list of the target
              # that this object was associated to.
              if previous = send(reflection.name)
                previous.send(reflection.inverse.uuids_getter).delete(self.uuid)
              end
              # Now assign this object to the new object
              object.send(reflection.inverse.uuids_getter) << self.uuid if object
            end
          else
            attribute(reflection.uuid_attribute, reflection.uuid_getter)
            define_method(reflection.name) do
              @project.objects[send(reflection.uuid_getter)]
            end
            define_method(reflection.singular_setter) do |object|
              send(reflection.uuid_setter, object.uuid)
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
        has_many :buildFiles, :inverse_of => :file
        has_one :group, :inverse_of => :children

        def self.new_static_library(project, productName)
          new(project, nil, {
            "path"             => "lib#{productName}.a",
            "includeInIndex"   => "0", # no idea what this is
            "explicitFileType" => "archive.ar",
            "sourceTree"       => "BUILT_PRODUCTS_DIR",
          })
        end

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

        has_many :children, :class => PBXFileReference do |object|
          if object.is_a?(Pod::Xcode::Project::PBXFileReference)
            # Associating the file to this group through the inverse
            # association will also remove it from the group it was in.
            object.group = self
          else
            # TODO What objects can actually be in a group and don't they
            # all need the above treatment.
            childReferences << object.uuid
          end
        end

        def initialize(*)
          super
          self.sourceTree ||= '<group>'
          self.childReferences ||= []
        end

        def files
          list_by_class(childReferences, Pod::Xcode::Project::PBXFileReference) do |file|
            file.group = self
          end
        end

        def source_files
          files = self.files.reject { |file| file.buildFiles.empty? }
          list_by_class(childReferences, Pod::Xcode::Project::PBXFileReference, files) do |file|
            file.group = self
          end
        end

        def groups
          list_by_class(childReferences, Pod::Xcode::Project::PBXGroup)
        end

        def <<(child)
          children << child
        end
      end

      class PBXBuildFile < PBXObject
        attributes :settings
        has_one :file, :uuid => :fileRef
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

        has_many :buildPhases
        has_many :dependencies # TODO :class => ?
        has_many :buildRules # TODO :class => ?
        has_one :buildConfigurationList
        has_one :product, :uuid => :productReference

        def self.new_static_library(project, productName)
          # TODO should probably switch the uuid and attributes argument
          target = new(project, nil, 'productType' => STATIC_LIBRARY, 'productName' => productName)
          target.product = project.files.new_static_library(productName)
          target.buildPhases.add(PBXSourcesBuildPhase)

          buildPhase = target.buildPhases.add(PBXFrameworksBuildPhase)
          project.groups.find { |g| g.name == 'Frameworks' }.files.each do |framework|
            buildPhase.files << framework.buildFiles.new
          end

          target.buildPhases.add(PBXCopyFilesBuildPhase, 'dstPath' => '$(PUBLIC_HEADERS_FOLDER_PATH)')
          target
        end

        # You need to specify a product. For a static library you can use
        # PBXFileReference.new_static_library.
        def initialize(project, *)
          super
          self.name ||= productName
          self.buildRuleReferences  ||= []
          self.dependencyReferences ||= []
          self.buildPhaseReferences ||= []

          unless buildConfigurationList
            self.buildConfigurationList = project.objects.add(XCConfigurationList)
            # TODO or should this happen in buildConfigurationList?
            buildConfigurationList.buildConfigurations.new('name' => 'Debug')
            buildConfigurationList.buildConfigurations.new('name' => 'Release')
          end
        end

        alias_method :_product=, :product=
        def product=(product)
          self._product = product
          product.group = @project.products
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
        has_one :baseConfiguration, :uuid => :baseConfigurationReference

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
        has_many :buildConfigurations

        def initialize(*)
          super
          self.buildConfigurationReferences ||= []
        end
      end

      class PBXProject < PBXObject
        has_many :targets, :class => PBXNativeTarget
        has_one :products, :singular_name => :products, :uuid => :productRefGroup, :class => PBXGroup
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

      def initialize(xcodeproj = nil)
        if xcodeproj
          file = File.join(xcodeproj, 'project.pbxproj')
          @plist = NSMutableDictionary.dictionaryWithContentsOfFile(file.to_s)
        else
          @plist = {
            'archiveVersion' => '1',
            'classes' => {},
            'objectVersion' => '46',
            'objects' => {}
          }
          self.root_object = objects.add(Xcode::Project::PBXProject, {
            'attributes' => { 'LastUpgradeCheck' => '0420' },
            'compatibilityVersion' => 'Xcode 3.2',
            'developmentRegion' => 'English',
            'hasScannedForEncodings' => '0',
            'knownRegions' => ['en'],
            'mainGroup' => groups.new.uuid,
            'projectDirPath' => '',
            'projectRoot' => '',
            'targets' => []
          })
        end
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

      def root_object
        objects[@plist['rootObject']]
      end

      def root_object=(object)
        @plist['rootObject'] = object.uuid
      end

      def groups
        objects.select_by_class(PBXGroup)
      end
      
      def main_group
        objects[root_object.attributes['mainGroup']]
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

      def add_system_framework(name)
        files.new({
          'lastKnownFileType' => 'wrapper.framework',
          'name' => "#{name}.framework",
          'path' => "System/Library/Frameworks/#{name}.framework",
          'sourceTree' => 'SDKROOT'
        })
      end

      def build_files
        objects.select_by_class(PBXBuildFile)
      end

      def targets
        # Better to check the project object for targets to ensure they are
        # actually there so the project will work
        root_object.targets
      end

      def products
        root_object.products
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
