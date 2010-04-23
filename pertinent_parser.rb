$i = 0

class Rule
    attr_accessor :range, :name, :children, :parent
    def initialize(range, name, children=[], parent=nil)
        @range = range.to_a
        @name = name
        @children = children
        @parent = parent
    end
    def add(new_rule)
        intersection = @range & new_rule.range
        if intersection === new_rule.range
            $i += 1
            puts "#{'--'*$i}#{@name}(#{@range[0]}..#{@range[-1]}) contains #{new_rule.name}(#{new_rule.range[0]}..#{new_rule.range[-1]})"
            if @children.empty?
                @children << new_rule
                new_rule.parent = self
            else
                result = new_rule
                @children.each do |child|
                   result = child.add(result)
                   break if result == :successful
                end
                if result != :successful
                    @children << result
                    result.parent = self
                end
            end
            $i -= 1
            return :successful
        elsif intersection === @range
            $i += 1
            puts "#{'--'*$i}#{@name}(#{@range[0]}..#{@range[-1]}) is inside #{new_rule.name}(#{new_rule.range[0]}..#{new_rule.range[-1]})"
            if @parent.nil?
                new_rule.add self
                return new_rule
            else
                children = @parent.children
                @parent.children = [new_rule]
                children.each do |child|
                    result = new_rule.add child
                    if result != :successful
                        @parent.children << result
                    end
                end
            end
            $i -= 1
            return :successful
        elsif intersection.empty?
            $i += 1
            puts "#{'--'*$i}#{@name}(#{@range[0]}..#{@range[-1]}) doesn't overlap with #{new_rule.name}(#{new_rule.range[0]}..#{new_rule.range[-1]})"
            $i -= 1
            return new_rule
        else
            $i += 1
            puts "#{'--'*$i}#{@name}(#{@range[0]}..#{@range[-1]}) partially overlaps with #{new_rule.name}(#{new_rule.range[0]}..#{new_rule.range[-1]})"
            difference = new_rule.range - intersection
            self.add Rule.new(intersection, new_rule.name)
            $i -= 1
            return Rule.new(difference, new_rule.name)
        end
    end
end

def rule(s, e, n)
    Rule.new((s..e), n)
end

def print_rule rule, depth=0
    puts ("--" * depth) + rule.name + ": " + (rule.range[0]..rule.range[-1]).to_s
    rule.children.each do |child|
        print_rule child, depth + 1
    end
    return nil
end

def dispr rule, frame=nil, depth=0, stack=nil
    frame ||= rule.range
    stack ||= [" " * frame.size]
    stack[depth] ||= " " * frame.size
    stack[depth] = do_a_merge(stack[depth], frame.map {|n| rule.range.include?(n) ? rule.name : " "}.join)
    rule.children.each do |child|
        stack = merge_stacks(stack, dispr(child, frame, depth + 1, stack))
    end
    return stack
end

def display_stack stack
    (1..stack[0].size).each do |i|
        print i % 10
    end
    puts
    stack.each do |line|
        puts line
    end
end

def disp rule
    display_stack(dispr(rule))
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
