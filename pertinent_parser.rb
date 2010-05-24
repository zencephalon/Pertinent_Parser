require "hpricot"

def offset_to_r(o)
    (o[0]..o[1]-1)
end

String.class_eval do
    def replace_nth! srch, n, rpl=nil, &rplf
        rest, right = "", self
        (n-1).times do
            part = right.partition(srch)
            rest << part[0..1].join
            right = part[2]
        end
        return replace(rest + right.sub(srch, rpl)) if rpl
        return replace(rest + right.sub(srch, rplf[srch]))
    end
end


def range_from_specification context, target, number
    count, position = 0, 0
    stored = []
    while (match = context.match(target, position)) do
        temp = match.offset 0
        position += 1; count += 1 if temp != stored
        return offset_to_r(temp) if count == number
        stored = temp
    end
end

def specification_from_range context, range
    i = 0
    target = context[range]
    until range == range_from_specification(context, target, i)
        i += 1
    end
    return [target, i]
end

class Hpricot::Elem
    def stag
        "<#{name}#{attributes_as_html}" +
        ((empty? and not etag) ? " /" : "") +
        ">"
    end
end


# Better write our own traversal function so that we can screw with the HTML representation the way we like.
def extract(html)
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

class Transform
    attr_accessor :type, :property
    attr_accessor :transformed, :original
    def initialize type, property
        @type, @property = type, property
    end
    def split(n)
        if @type == :replacement
            return [Transform.new(:replacement, @property[0..n-1]), Transform.new(:replacement, @property[n..-1])]
        elsif @type == :wrap
            return [self, self.dup]
        end
    end
    def apply(s)
        if @type == :identity
            return s
        elsif @type == :replacement
            return @property
        elsif @type == :wrap
            return @property[0] + s + @property[1]
        end
    end
end

class Rule
    attr_accessor :name, :children, :parent
    attr_accessor :target, :number
    attr_accessor :context
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

def wrap(context, target, number, tag)
    range = range_from_specification(context, target, number)
    wrap_(range, tag)
end

def wrap_(range, tag)
    transform = Transform.new(:wrap, [tag, "</"+tag.match(/<(\S*)(\s|>)/)[1]+">" ])
    r = Rule.new(range, transform)
end

def replace(context, target, number, replacement)
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
end

def text(s)
    r = Rule.new((0..s.size-1), Transform.new(:identity, ["id"]))
    t = Text.new(s)
    t.rule = r
    t
end
