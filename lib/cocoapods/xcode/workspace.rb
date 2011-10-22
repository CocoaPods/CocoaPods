framework 'Foundation'

module Pod
  module Xcode
    class Workspace
      def initialize(*projpaths)
        @projpaths = projpaths
      end
      
      def <<(projpath)
        @projpaths << projpath
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
    end
  end
end
