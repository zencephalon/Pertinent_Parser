require "hpricot"
require "pertinent_parser/transform"
require "pertinent_parser/rule"
require "pertinent_parser/text"


class Hpricot::Elem
    def stag
        "<#{name}#{attributes_as_html}" +
        ((empty? and not etag) ? " /" : "") +
        ">"
    end
end

module PertinentParser
  class << self
    # Better write our own traversal function so that we can screw with the HTML representation the way we like.
    def html(html)
      doc = Hpricot(html)
      d = 0
      t = text(doc.inner_text)
      doc.traverse_all_element do |elem|
        if elem.text?
          #puts elem.inner_text
          d += elem.inner_text.size
        else
          #puts elem.stag
          t + wrap_(d...d+elem.inner_text.size, elem.stag)
          #puts "#{d}..#{d+elem.inner_text.size}"
        end
      end
      t
    end

    def text(s)
      r = Rule.new((0..s.size-1), Transform.new(:identity, ["id"]))
      t = Text.new(s)
      t.rule = r
      t
    end

    def offset_to_r(o)
      (o[0]..o[1]-1)
    end

    def range_from_specification context, target, number
      count, position = 0, 0
      stored = []
      re = Regexp.new(Regexp.escape(target))
      while (match = context.match(re , position)) do
        temp = match.offset 0
        position += 1; count += 1 if temp != stored
        return offset_to_r(temp) if count == number
        stored = temp
      end
    end

    def new_wrap(context, target, number, tag)
      range = range_from_specification(context, target, number)
      wrap_(range, tag)
    end
  end
end




def rule(range, transform)
    Rule.new(range, transform)
end


def wrap_(range, tag)
    transform = Transform.new(:wrap, [tag, "</"+tag.match(/<(\S*)(\s|>)/)[1]+">" ])
    r = Rule.new(range, transform)
end

def new_replace(context, target, number, replacement)
    range = range_from_specification(context, target, number)
    transform = Transform.new(:replacement, replacement)
    r = Rule.new(range, transform)
end



