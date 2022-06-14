LabelValue = Struct.new(:label, :value) do
  def initialize(string)
    super(*string.split("="))
  end

  def <=>(other)
    label <=> other.label
  end
end
