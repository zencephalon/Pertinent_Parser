require "hpricot"
require "pertinent_parser/transform"

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
  end
end



class Rule
    attr_accessor :name, :children, :parent
    attr_accessor :transform
    attr_accessor :range
    def initialize(range, transform=nil, children=[], parent=nil)
        @range = range.to_a
        @children = children
        @parent = parent
        @transform = transform
    end
    def <=>(r)
        range.first <=> r.range.first
    end
    def apply_recur(s, offset=0)
        pre = offset
        @children.each do |child|
            offset += child.apply_recur(s, offset)
        end
        # This was an optimization gone wrong. Sorry. Applies the transformation to the portion of the text.
        return (s[@range.first+pre..@range.last+offset] = @transform.apply(s[@range.first+pre..@range.last+offset])).size - range.size
    end
    def apply(str)
        s = str.dup
        apply_recur(s)
        return s
    end
    def +(text)
        add(text.rule)
        return text
    end
    def add(new_rule)
        intersection = range & new_rule.range
        if intersection == new_rule.range
            contain = []
            input = new_rule
            @children.each do |child|
                result = child.add(input)
                case result
                when Rule        
                    input = result
                when :inside     
                    return :inside
                when :contain    
                    contain << child
                when :outside
                end
            end
            @children -= contain
            contain.each do |child|
                input.add child
            end
            @children << input
            @children.sort!
            return :inside
        elsif intersection.empty?
            return :outside
        elsif intersection == range
            if @parent.nil?
                children = new_rule.children
                new_rule.children = [self]
                children.each do |child|
                    new_rule.add child
                end
                return new_rule
            end
            return :contain
        else
            difference = new_rule.range - intersection
            transforms = new_rule.transform.split(difference.size)
            if intersection.first < difference.first
                inter_tran, diff_tran = transforms
            else
                diff_tran, inter_tran = transforms
            end
            self.add(Rule.new(intersection, inter_tran))
            return Rule.new(difference, diff_tran)
        end
    end
end

def rule(range, transform)
    Rule.new(range, transform)
end

def new_wrap(context, target, number, tag)
    range = range_from_specification(context, target, number)
    wrap_(range, tag)
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

class Text < String
    attr_accessor :rule
    def apply
        @rule.apply(self)
    end
    undef +
    def +(new_rule)
        @rule.add(new_rule)
    end
    def apply
        @rule.apply(self)
    end
    def wrap_in(tag, target, number=1)
        self.+(new_wrap(self, target, number, tag))
    end
    def replace(replacement, target, number=1)
        self.+(new_replace(self, target, number, replacement))
    end
    def wrap_out(tag, target, number=1)
        new_wrap(self, target, number, tag).+(self)
    end
end

