require "atom/element"

module XHTML
  NS = "http://www.w3.org/1999/xhtml"
end

module Atom 
  # An Atom::Element representing a text construct.
  # It has a single attribute, "type", which accepts values
  # "text", "html" and "xhtml"

  class Text < Atom::Element
    attrb :type

    def initialize value, name # :nodoc:
      @content = value
      @content ||= "" # in case of nil
      self["type"] = "text"
      
      super name
    end

    def to_s
      if self["type"] == "xhtml" 
        @content.children.to_s
      else
        @content.to_s
      end
    end

    # XXX do something different
    def text # :nodoc:
      to_s
    end

    # returns a string suitable for dumping into an HTML document
    def html
      if self["type"] == "xhtml" or self["type"] == "html"
        to_s
      elsif self["type"] == "text"
        REXML::Text.new(to_s).to_s
      end
    end

    # attepts to parse the content and return it as an array of REXML::Elements
    def xml
      if self["type"] == "xhtml"
        @content.children
      elsif self["type"] == "text"
        [self.to_s]
      else
        # XXX - hpricot goes here?
        raise "I haven't implemented this yet"
      end
    end

    def inspect # :nodoc:
      "'#{to_s}'##{self['type']}"
    end

    def []= key, value # :nodoc:
      if key == "type"
        unless valid_type? value
          raise "atomTextConstruct type '#{value}' is meaningless"
        end

        if value == "xhtml"
          begin
            parse_xhtml_content
          rescue REXML::ParseException
            raise "#{@content.inspect} can't be parsed as XML"
          end
        end
      end

      super(key, value)
    end
    
    def to_element # :nodoc:
      e = super

      if self["type"] == "text"
        e.attributes.delete "type"
      end

      # this should be done via inheritance
      unless self.class == Atom::Content and self["src"]
        c = convert_contents e

        if c.is_a? String
          e.text = c
        elsif c.is_a? REXML::Element
          e << c.dup
        else
          raise RuntimeError, "atom:#{local_name} can't contain type #{@content.class}"
        end
      end

      e
    end
    
    private
    def convert_contents e
      if self["type"] == "xhtml"
        @content
      elsif self["type"] == "text" or self["type"].nil?
        REXML::Text.normalize(@content.to_s)
      elsif self["type"] == "html"
        @content.to_s
      end
    end
    
    def valid_type? type
      ["text", "xhtml", "html"].member? type
    end

    def parse_xhtml_content xhtml = nil
      xhtml ||= @content

      @content = if xhtml.is_a? REXML::Element
        if xhtml.name == "div" and xhtml.namespace == XHTML::NS
          xhtml.dup
        else
          elem = REXML::Element.new("div")
          elem.add_namespace(XHTML::NS)

          elem << xhtml.dup

          elem
        end
      elsif xhtml.is_a? REXML::Document
        parse_xhtml_content xhtml.root
      else
        div = REXML::Document.new("<div>#{@content}</div>")
        div.root.add_namespace(XHTML::NS)

        div.root
      end
    end
  end

  # Atom::Content behaves the same as an Atom::Text, but for two things:
  #
  # * the "type" attribute can be an arbitrary media type
  # * there is a "src" attribute which is an IRI that points to the content of the entry (in which case the content element will be empty)
  class Content < Atom::Text
    attrb :src

    private
    def valid_type? type
      super or type.match(/\//)
    end

    def convert_contents e
      s = super

      s ||= if @content.is_a? REXML::Document
        @content.root
      elsif @content.is_a? REXML::Element
        @content
      else
        REXML::Text.normalize(@content.to_s)
      end

      s
    end
  end
end