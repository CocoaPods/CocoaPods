framework 'Foundation'
require 'fileutils'

module Pod
  module Xcode
    class Workspace
      def initialize(*projpaths)
        @projpaths = projpaths
      end
      
      def self.new_from_xcworkspace(path)
        begin
          from_s(File.read(File.join(path, 'contents.xcworkspacedata')))
        rescue Errno::ENOENT
          new
        end
      end
      
      def self.from_s(xml)
        doc = NSXMLDocument.alloc.initWithXMLString(xml, options:0, error:nil)
        projpaths = doc.nodesForXPath("/Workspace/FileRef", error:nil).map do |node|
          node.attributeForName("location").stringValue.sub(/^group:/, '')
        end
        new(*projpaths)
      end
      
      attr_reader :projpaths
      
      def <<(projpath)
        @projpaths << projpath
      end
      
      def include?(projpath)
        @projpaths.include?(projpath)
      end
      
      TEMPLATE = %q[<?xml version="1.0" encoding="UTF-8"?><Workspace version="1.0"></Workspace>]
      def to_s
        doc = NSXMLDocument.alloc.initWithXMLString(TEMPLATE, options:0, error:nil)
        @projpaths.each do |projpath|
          el = NSXMLNode.elementWithName("FileRef")
          el.addAttribute(NSXMLNode.attributeWithName("location", stringValue:"group:#{projpath}"))
          doc.rootElement.addChild(el)
        end
        NSString.alloc.initWithData(doc.XMLData, encoding:NSUTF8StringEncoding)
      end
      
      def save_as(path)
        FileUtils.mkdir_p(path)
        File.open(File.join(path, 'contents.xcworkspacedata'), 'w') do |out|
          out << to_s
        end
      end
    end
  end
end
