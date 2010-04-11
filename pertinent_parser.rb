module PertinentParser
    class Rule
        attr_accessor :function, :target, :position

        def initialize target, position = 1, context, &function
            @target = target
            @function = function
            @position = position
            @context = context
        end

        def size
            @target.size
        end

        def r_match words, depth
            if words.empty?
                return [""]
            end
            if words.take(size) == @target
                if depth == 1
                    return words.take(size) + Array.new(words.size - size, "")
                else
                    return Array.new(size, "") + r_match(words.drop(size), depth - 1)
                end
            else
                return [""] + r_match(words.drop(1), depth)
            end
        end

        def match
            r_match @context, @position
        end

        def r_range words, depth
            if words.empty?
                return -1
            end
            if words.take(size) == @target
                if depth == 1
                    return 0
                else
                    return size + r_range(words.drop(size), depth - 1)
                end
            else
                return 1 + r_range(words.drop(1), depth)
            end
        end

        def range
            i = r_range(@context, @position)
            (i...i + size)
        end

        def apply
            c = @context.dup
            c[range] = @function.call(@target.join(" ")).split
            c
        end
        def apply_s s
            s[range] = @function.call(@target.join(" ")).split
        end

        def + rule
            rule.context = @context

            original_matched = match
            new_matched = rule.match

            intersection = inter(original_matched, new_matched)

            if intersection.join == ""
                return [self, rule]
            else
                inner_target = intersection.reject {|s| s == ""}
                r_inner = Rule.new(inner_target, find_position(intersection, @context), @context, &@function)
                r_inner.apply_s(@context)
                r_inner.apply_s(@target)
                difference = diff(original_matched, intersection) 
                if difference.join != ""
                    out_target = difference.reject {|s| s == ""} 
                    r_outer = Rule.new(out_target, find_position(difference, @context), @context, &@function)
                end
            end

          #  else
          #      inner_target = intersection.reject {|s| s == ""}
          #      new_context = rule.apply
          #      r_inner = Rule.new(inner_target, find_position(intersection, @context), @context, &@function)
          #      difference = diff(original_matched, intersection) 
          #      if difference.join != ""
          #          out_target = difference.reject {|s| s == ""} 
          #          r_outer = Rule.new(out_target, find_position(difference, @context), @context, &@function)
          #          return [r_inner, r_outer]
          #      end
          #      return [r_inner]
          #  end
        end
    end

    class Transform
        attr_accessor :rules, :input
        def initialize input
            @input = input
            @rules = []
        end
        def add_rule target, position=1, &function 
            r = Rule.new(target, position, @input, &function)
            rules = [r]
            @rules.each do |rule|
                rules += (rule + r)
            end
            @rules = rules
        end
        def apply
            c = @input.dup
            @rules.each {|r| r.apply_s(c)}
            c
        end
    end

    def find_position target, words
        i = 1
        r = Rule.new(target.reject {|s| s == ""}, 1, words)
        while (m = r.r_match(words, i)).join != ""
            return i if target == m
            i += 1
        end 
    end

    def inter a, b
        a.each_index.inject([]) do |c, i|
            c << (a[i] == b[i] ? a[i] : "")
        end
    end

    def diff a,b
        a.each_index.inject([]) do |c, i|
            c << (a[i] != b[i] ? a[i] : "")
        end
    end
end
