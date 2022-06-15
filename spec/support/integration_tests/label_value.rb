LabelValue = Struct.new(:label, :value, keyword_init: true) do
  def initialize(string)
    label, value = string.split("=")
    super(label: label, value: value)
  end

  def <=>(other)
    label <=> other.label
  end
end
