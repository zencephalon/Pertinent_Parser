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
        if @type == :replacement
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
#    def initialize(range, name, children=[], parent=nil)
#        @range = range.to_a
#        @name = name
#        @children = children
#        @parent = parent
#    end
    def initialize(context, name, target, number)
        @context = context
        @target = target
        @number = number
        @name = name
        @children = []
        @parent = nil
    end
    def range
        (range_from_specification @context, @target, @number).to_a
    end
    def <=>(r)
        range.first <=> r.range.first
    end
    def apply

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
            #@children.sort!
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
            target, number = specification_from_range(intersection.first..intersection.last)
            self.add(Rule.new(@context, new_rule.name, target, number))
            target, number = specification_from_range(difference.first..difference.last)
            return Rule.new(@context, new_rule.name, target, number)
        end
    end
end

def rule(context, name, target, number)
    Rule.new(context, name, target, number)
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
    display_stack(dispr(rule, (0..rule.context.size-1).to_a), rule)
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
