class Rule
    attr_accessor :range, :children, :parent
    def initialize(range, children=[], parent=nil)
        @range = range.to_a
        @children = children
        @parent = parent
    end
    def add new_rule
        intersection = @range & new_rule.range
        puts intersection
    end
end
