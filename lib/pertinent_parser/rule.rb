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
