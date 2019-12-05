# frozen_string_literal: true

require 'cocoapods/xcode/xcframework/xcframework_slice'

module Pod
  module Xcode
    class XCFramework
      # @return [Pathname] path the path to the .xcframework on disk
      #
      attr_reader :path

      # @return [Pod::Version] the format version of the .xcframework
      #
      attr_reader :format_version

      # @return [Array<XCFramework::Slice>] the slices contained inside this .xcframework
      #
      attr_reader :slices

      # @return [Hash] the contents of the parsed plist
      #
      attr_reader :plist

      # Initializes an XCFramework instance with a path on disk
      #
      # @param [Pathname, String] path
      #        The path to the .xcframework on disk
      #
      # @return [XCFramework] the xcframework at the given path
      #
      def initialize(path)
        @path = Pathname.new(path).tap do |p|
          raise 'Absolute path is required' unless p.absolute?
        end

        @plist = Xcodeproj::Plist.read_from_path(plist_path)
        parse_plist_contents
      end

      # @return [Pathname] the path to the Info.plist
      #
      def plist_path
        path + 'Info.plist'
      end

      # @return [String] the basename of the framework
      #
      def name
        File.basename(path, '.xcframework')
      end

      # @return [Boolean] true if any slices use dynamic linkage
      #
      def includes_dynamic_slices?
        slices.any? { |slice| Xcode::LinkageAnalyzer.dynamic_binary?(slice.binary_path) }
      end

      # @return [Boolean] true if any slices use dynamic linkage
      #
      def includes_static_slices?
        slices.any? { |slice| !Xcode::LinkageAnalyzer.dynamic_binary?(slice.binary_path) }
      end

      private

      def parse_plist_contents
        @format_version = Pod::Version.new(plist['XCFrameworkFormatVersion'])
        @slices = plist['AvailableLibraries'].map do |library|
          identifier = library['LibraryIdentifier']
          relative_path = library['LibraryPath']
          archs = library['SupportedArchitectures']
          platform_name = library['SupportedPlatform']
          platform_variant = library['SupportedPlatformVariant']

          slice_path = path.join(identifier).join(relative_path)
          XCFramework::Slice.new(slice_path, identifier, archs, platform_name, platform_variant)
        end
      end
    end
  end
end
