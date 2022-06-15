MetricsLine = Struct.new(:bucket_name, :label_values, :counted, keyword_init: true) do
  def initialize(string)
    match = string.match(/(?<bucket_name>[\w_]+){(?<label_values>.+)}\s(?<counted>\d)/)
    label_values_array = match[:label_values].split(",").map { |l| LabelValue.new(l) }.sort
    super(
      bucket_name: match[:bucket_name],
      label_values: label_values_array,
      counted: match[:counted]
    )
  end
end
