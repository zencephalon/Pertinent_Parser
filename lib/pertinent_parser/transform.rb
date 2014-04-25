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
    if @type == :identity
      return s
    elsif @type == :replacement
      return @property
    elsif @type == :wrap
      return @property[0] + s + @property[1]
    end
  end
end   
