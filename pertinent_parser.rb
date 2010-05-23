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
    count, position = 1, 0
    while (match = context.match(target, position)) do
        return offset_to_r(match.offset 0) if count == number
        position = match.offset(0)[1]
        count += 1
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

def extract(html)
    doc = Hpricot(html)
    doc.traverse_all_element do |elem|
        unless elem.html.empty?
            tags = elem.to_html.gsub(elem.html, "")
            puts elem.stag
            puts elem.etag
            puts tags
        end
    end
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
        # = str.dup
        @children.each do |child|
            offset += child.apply_recur(s, offset)
        end
        if @children.empty?
            puts "#{@range.first+offset}:#{@range.last+offset}"
            transform = @transform.apply(s[@range.first+offset..@range.last+offset]) 
            s[@range.first+offset..@range.last+offset] = transform
        else
            transform = @transform.apply(s[@range.first..@range.last + offset]) 
            s[@range.first..@range.last + offset] = transform
        end
        return (transform.size - range.size)
    end
    def apply(str)
        s = str.dup
        apply_recur(s)
        return s
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

def print_rule rule, depth=0
    puts ("--" * depth) + rule.name + ": " + (rule.range[0]..rule.range[-1]).to_s
    rule.children.each do |child|
        print_rule child, depth + 1
    end
    nil
end

def dispr rule, frame=nil, depth=0, stack=nil
    frame ||= rule.range
    stack ||= [" " * frame.size]
    stack[depth] ||= " " * frame.size
    stack[depth] = do_a_merge(stack[depth], frame.map {|n| rule.range.include?(n) ? rule.name : " "}.join)
    rule.children.each do |child|
        stack = merge_stacks(stack, dispr(child, frame, depth + 1, stack))
    end
    stack
end

def display_stack stack, rule
    #(1..stack[0].size).each do |i|
    #    print i % 10
    #end
    puts rule.context
    stack.each do |line|
        puts line
    end
end

def disp rule
    display_stack(dispr(rule, (1..rule.context.size).to_a), rule)
    nil
end

def do_a_merge a, b
    c = ""
    (0..a.size-1).each do |i|
        c << (a[i] == " " ? b[i] : a[i])
    end
    c
end

def merge_stacks a, b
    c = b.dup
    a.each_index do |k|
        c[k] = do_a_merge a[k], c[k]
    end
    c
end

def wrap(context, target, number, tag)
    range = range_from_specification(context, target, number)
    transform = Transform.new(:wrap, [tag, tag])
    r = Rule.new(range, "w", transform)
end

def replace(context, target, number, replacement)
    range = range_from_specification(context, target, number)
    transform = Transform.new(:replacement, replacement)
    r = Rule.new(range, "w", transform)
end

class Text < String
    attr_accessor :rule
    def apply
        @rule.apply(self)
    end
end

def text(s)
    r = Rule.new((0..s.size-1), Transform.new(:identity, nil))
    t = Text.new(s)
    t.rule = r
    t
end
