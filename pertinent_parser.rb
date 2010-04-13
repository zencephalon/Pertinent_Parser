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

            #FIXME: Adding rules with the whole children thing is wrong, you get duplicates. Make intersection.empty? return nil instead, and check status of returned shit. fuck.

            # Case: the rules do not intersect at all. They can both be applied safely separately, as their
            # target areas are entirely distinct.
            if intersection.empty?
                #[self, rule]
                rule
            # Case: the second rule is entirely inside the first. It will become a child of the first rule,
            # but first it must be recursively added to the children of the first rule.
            elsif intersection == that_match
                if @children.empty?
                    @children << rule
                    return true
                else
                    @children.each do |child|
                        res = child.+(rule, context)
                        if res != rule
                           if res == true
                               return true
                           elsif res == false
                               @children.delete(child)
                           elsif res.is_a?(Array)
                               @children.delete(child)
                               rule = res[1]
                           else
                               rule = res
                           end
                        end
                    end
                    @children << rule
                    return true
                end
            # Case: the first rule is entirely inside the first. This is symmetrical with the previous case.
            elsif intersection == this_match
                rule.+(self, context)
                return false
            # Case: the two rules have non-trivial intersection. The part of the first rule inside the second
            # rule is added as a child to the second rule. The part of the first rule outside the second rule
            # may be safely applied on its own.
            else
                inner_target = context[(intersection.first..intersection.last)] 
                puts @target
                r_in = Rule.new(inner_target, PertinentParser::find_position(inner_target, intersection, context), &self.function)
                rule.+(r_in, context)
                difference = that_match - this_match
                outer_target = context[(difference.first..difference.last)] 
                r_out = Rule.new(outer_target, PertinentParser::find_position(outer_target, difference, context), &self.function)
                [false, r_out]
            end
        end
    end

    # A transform is a top level collection of rules and an input.
    # Rules added to a transform will operate with the input as their
    # context. This is important in the composition stage of adding 
    # rules.
    class Transform
        attr_accessor :rule, :input
        def initialize input
            @input = input
            @rule = Rule.new(@input) {|s| s}
        end

        # Short-hand method for composing new rules.
        # Takes two forms. Either add("target", "<tag attrs>")
        # which will create a function that maps "string" to
        # "<tag attrs>string</tag>", or add("target") {|s| do_whatever}
        # which takes a manually specified function.
        def add string, tag="", pos=1, &func
            if func.nil?
                func = proc do |s|
                    tag + s + "</" + tag.match(/<(\S*)(\s|>)/)[1] + ">"
                end
            end
            add_rule(string.split(""), pos, &func)
        end

        # Same as the block form of the short-hand method.
        def add_rule target, position=1, &function 
            r = Rule.new(target, position, &function)
            return false if r.range(@input).end > @input.size
            @rule.+(r, @input)
            true
        end

        # Apply each rule to the input, give the output.
        def apply
            c = @input.dup
            @rule.apply(c).join
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
        pos = 1
        while (range_pos = range_i(target, words, pos)).end <= words.size
            return pos if range == range_pos.to_a
            pos += 1
        end
    end

    # Creates a transform instance given HTML. The input of the transform
    # will be stripped down plain text, and the rules will be such that
    # applying the transform will return to the original HTML.
    def self.html(input)
       transformation = Transform.new(extract_text(input))
       html_transform(transformation, input)
       transformation
    end

    # Extract rules from HTML tag occurences.
    def self.html_transform(t, input)
        #left, open_tag, contents, close_tag, right = 
        left, open_tag, contents, close_tag, right = match(input)
        if open_tag.empty?
            left
        else
            p = proc {|s| "#{open_tag}#{s}#{close_tag}"}
            s = html_transform(t, contents)
            t.add_rule(s.split(""), &p)
            left + s + html_transform(t, right)
        end
    end

    # Return the plain text from an HTML document.
    def self.extract_text(input)
        left, tag, middle, _, right = match(input)
            (tag.empty? and left.empty?) ? [] : left.split("") + extract_text(middle) + extract_text(right)
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
