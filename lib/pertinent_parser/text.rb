class Text < String
  attr_accessor :rule

  # Return the HTML after all rules are applied
  def apply
    @rule.apply(self)
  end
  
  undef +
    def +(new_rule)
      @rule.add(new_rule)
  end

  # Wrap text, falling inside of existing boundaries
  def wrap_in(tag, target, number=1)
    self.+(PertinentParser.new_wrap(self, target, number, tag))
  end

  def replace(replacement, target, number=1)
    self.+(PertinentParser.new_replace(self, target, number, replacement))
  end

  # Wrap text, falling outside of existing boundaries
  def wrap_out(tag, target, number=1)
    PertinentParser.new_wrap(self, target, number, tag).+(self)
  end
end 
