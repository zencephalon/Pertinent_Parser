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
        def + rule, context, right=true
            this_match = range(context).to_a
            that_match = rule.range(context).to_a
            intersection = this_match & that_match

            case intersection
            # Case: no intersection at all. Return the :outside status indicating r2 lies outside r1.
            # r2 will be added to r1's parent's children (i.e. adjavent to r1).
            when [] then :outside
            # Case: r2 lies entirely inside r1. This is where the meat of the algorithm happens.
            when that_match
                # If r1 has no children, then r2 is simply made r1's child.
                if @children.empty?
                    @children << rule
                else
                    status, partial_rule = nil, nil

                    # If r1 has children, then r2 can potentially conflict with one of them, so we
                    # recur into the children. If we _only_ receive :outside as a status, then r2 
                    # safely lies outside of every child, and it can be added to r1.children. If we
                    # receive any other status, we immediately break for more processing.
                    @children.each do |child|
                       status, partial_rule = child.+(rule, context, right)
                       break unless status == :outside
                    end
                    
                    if status == :swap or partial_rule
                        # This step is never taken if we have left-hand precedence set, and it is
                        # only taken if we 
                        if right
                           kids = @children
                           @children = [rule]
                           kids.each do |kid|
                               rule.+(kid, context, right)
                           end
                        end
                       self.+(partial_rule, context, right) if partial_rule and right
                       @children << partial_rule if partial_rule and !right
                    elsif status == :outside
                        @children << rule
                    end
                end
                return :inside
            when this_match then :swap
            else
                split_rule = proc do |primary, secondary, secondary_match|
                    inner_target = context[(intersection.first..intersection.last)] 
                    r_in = Rule.new(inner_target, PertinentParser::find_position(inner_target, intersection, context), &secondary.function)
                    primary.+(r_in, context, right)
                    difference = secondary_match - intersection
                    outer_target = context[(difference.first..difference.last)] 
                    r_out = Rule.new(outer_target, PertinentParser::find_position(outer_target, difference, context), &secondary.function)
                    return :partial, r_out
                end
                right ? split_rule.call(rule, self, this_match) : split_rule.call(self, rule, that_match)
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
        def add string, tag="", right=true, pos=1, &func
            if func.nil?
                func = proc do |s|
                    tag + s + "</" + tag.match(/<(\S*)(\s|>)/)[1] + ">"
                end
            end
            add_rule(string.split(""), right, pos, &func)
        end

        # Same as the block form of the short-hand method.
        def add_rule target, right=true, position=1, &function 
            r = Rule.new(target, position, &function)
            return false if r.range(@input).end > @input.size
            @rule.+(r, @input, right)
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

    def self.r_range target, words, position
        depth, pos, size = 0, 1, target.size
        until ((match = (words[depth, size] == target)) and pos == position) or depth > (words.size - size)
            if match then depth += size; pos += 1 else depth += 1
            end
        end
        depth
    end

    # Returns the range of the ith occurence of target in words.
    def self.range_i target, words, position
        left = r_range(target, words, position)
        (left...left + target.size)
    end

    # Finds which occurence of target happens in the range in words.
    def self.find_position target, range, words
        pos = 1
        while (range_pos = range_i(target, words, pos)).end <= (words.size - target.size)
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
    def self.html_transform(transform, input)
        #left, open_tag, contents, close_tag, right = 
        left, open_tag, contents, close_tag, right = match(input)
        if open_tag.empty?
            left
        else
            func = proc {|contents| "#{open_tag}#{contents}#{close_tag}"}
            middle = html_transform(transform, contents)
            transform.add_rule(middle.split(""), &func)
            left + middle + html_transform(transform, right)
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
