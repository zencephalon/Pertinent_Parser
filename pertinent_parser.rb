# PertinentParser is a Ruby library for parsing and text transformations.
#
# Example usage:
#
#   require "pertinent_parser"
#   t = PertinentParser::html("<p>Hanlon's Razor: <i><em>never</em> attribute to malice that which can be adequately explained by stupidity</i>. Occam's Razor: <i>entia non sunt multiplicanda praeter necessitatem</i>.</p>")
#   t.text #=> "Hanlon's Razor: never attribute to malice that which can be adequately explained by stupidity. Occam's Razor: entia non sunt multiplicanda praeter necessitatem."
#   t.add("never attribute to malice that which can be adequately explained by stupidity.", "<q>") #=> true
#   t.add("entia non sunt multiplicanda praeter necessitatem.", "<q>") #=> true
#   t.add("War doesn't determine who is right, but rather who is wrong.", "<q>") #=> false
#   t.apply #=> "<p>Hanlon's Razor: <q><i><em>never</em> attribute to malice that which can be adequately explained by stupidity</i>.</q> Occam's Razor: <q><i>entia non sunt multiplicanda praeter necessitatem</i>.</q></p>"
#   t.add("Hanlon") {"Cynic"} #=> true
#   t.add("never") {"always"} #=> true
#   t.apply #=> "<p>Cynic's Razor: <q><i><em>always</em> attribute to malice that which can be adequately explained by stupidity</i>.</q> Occam's Razor: <i>entia non sunt multiplicanda praeter necessitatem</i>alway<q><i>entia non sunt multiplicanda praeter necessitatem</i>.</q></p>"
#
# TODO: memoize
module PertinentParser
    # A rule holds a target (the text to search for) a position (which occurence of the target in the text it should change) and a function which will be applied to the target text. It also holds a list of children. A child's target is by definition inside the parent's target, and a child will be before the parent.
    class Rule
        attr_accessor :function, :target, :position, :children

        # For internal use. 
        def initialize target, position = 1, &function
            @target = target
            @function = function
            @position = position
            @children = []
        end

        # Returns the range of the target within the context
        def range words
            i = PertinentParser::range_i(@target, words, @position)
        end

        # Recursively apply the children and the rule to a string.
        def apply s
            t, st = @target.dup, s.dup
            @children.each do |child|
                @target = child.apply @target
                st = child.apply st
            end
            st[range(st)] = @function.call(@target.join).split("")
            @target = t
            st
        end

        # Compose a rule.
        # For entirely overlapping rules or non-overlapping rules this operation is commutative.
        # It is _not_ commutative for partially overlapping rules. The second rule will take precedance,
        # that is, it will break the first rule into two parts to preserve itself.
        def + rule, context
            this_match = range(context).to_a
            that_match = rule.range(context).to_a
            intersection = this_match & that_match

            # Case: the rules do not intersect at all. They can both be applied safely separately, as their
            # target areas are entirely distinct.
            if intersection.empty?
                [self, rule]
            # Case: the second rule is entirely inside the first. It will become a child of the first rule,
            # but first it must be recursively added to the children of the first rule.
            elsif intersection == that_match
                if @children.empty?
                    @children << rule
                else
                    children = []
                    @children.each do |child|
                        children += child.+(rule, context)
                    end
                    @children = children.uniq
                end
                [self]
            # Case: the first rule is entirely inside the first. This is symmetrical with the previous case.
            elsif intersection == this_match
                rule.+(self, context)
                [rule]
            # Case: the two rules have non-trivial intersection. The part of the first rule inside the second
            # rule is added as a child to the second rule. The part of the first rule outside the second rule
            # may be safely applied on its own.
            else
                inner_target = @target[(intersection.first..intersection.last)] 
                r_in = Rule.new(inner_target, find_position(inner_target, intersection, context), &@function)
                rule.+(r_in, context)
                difference = this_match - that_match
                outer_target = @target[(difference.first..difference.last)] 
                r_out = Rule.new(outer_target, find_position(outer_target, difference, context), &@function)
                [rule, r_out]
            end
        end
    end

    # A transform is a top level collection of rules and an input.
    # Rules added to a transform will operate with the input as their
    # context. This is important in the composition stage of adding 
    # rules.
    class Transform
        attr_accessor :rules, :input
        def initialize input
            @input = input
            @rules = []
        end

        # Short-hand method for composing new rules.
        # Takes two forms. Either add("target", "<tag attrs>")
        # which will create a function that maps "string" to
        # "<tag attrs>string</tag>", or add("target") {|s| do_whatever}
        # which takes a manually specified function.
        def add string, tag="", pos=1, &func
            if func.nil?
                func = proc do |s|
                    tag + s + "</" + tag[/<(\S*)/][1] + ">"
                end
            end
            add_rule(string.split(""), pos, &func)
        end

        # Same as the block form of the short-hand method.
        def add_rule target, position=1, &function 
            r = Rule.new(target, position, &function)
            return false if r.range(@input).end > @input.size
            if @rules.empty?
                @rules << r
            else
                rules = []
                @rules.each do |rule|
                    rules += rule.+(r, @input)
                end
                @rules = rules.uniq
            end
            true
        end

        # Apply each rule to the input, give the output.
        def apply
            c = @input.dup
            @rules.each {|r| c = r.apply(c)}
            c.join
        end

        # Return the input.
        def text
            @input.join
        end
    end

    # Recursive helper function. See wrapper.
    def self.r_range target, words, depth
        if words.empty?
            -1
        elsif words.take(target.size) == target
            depth == 1 ? 0 : target.size + r_range(target, words.drop(target.size), depth - 1)
        else
            1 + r_range(target, words.drop(1), depth)
        end
    end

    # Returns the range of the ith occurence of target in words.
    def self.range_i target, words, i
        a = r_range(target, words, i)
        (a...a + target.size)
    end

    # Finds which occurence of target happens in the range in words.
    def self.find_position target, range, words
        i = 1
        while (m = range_i(target, words, i)).end <= words.size
            return i if range == m.to_a
            i += 1
        end
    end

    # Creates a transform instance given HTML. The input of the transform
    # will be stripped down plain text, and the rules will be such that
    # applying the transform will return to the original HTML.
    def self.html(input)
       t = Transform.new(extract_text(input))
       html_transform(t, input)
       t
    end

    # Extract rules from HTML tag occurences.
    def self.html_transform(t, input)
        #left, open_tag, contents, close_tag, right = 
        matched = match(input)
        if matched[1] == ""
            matched[0]
        else
            p = proc {|s| "#{matched[1]}#{s}#{matched[3]}"}
            s = html_transform(t, matched[2])
            t.add_rule(s.split(""), &p)
            matched[0] + s + html_transform(t, matched[4])
        end
    end

    # Return the plain text from an HTML document.
    def self.extract_text(input)
        if (matched = match(input))[1] == ""
            matched[0] == "" ? [] : matched[0].split("")
        else
            matched[0].split("") + extract_text(matched[2]) + extract_text(matched[4])
        end
    end

    # Match a pair of tags.
    def self.match(html=@html)
        first, open_tag, right = html.partition(/<.*?>/)
        score, contents, close_tag = 1, "", ""
        while right =~ /<.*?>/ 
            contents << close_tag
            left, close_tag, right = right.partition(/<.*?>/)
            contents << left
            score += ((close_tag =~ /<\/.*?>/) ? -1 : 1)
            break if score == 0
        end 
        [first, open_tag, contents, close_tag, right]
    end
end
