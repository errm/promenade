class CustomClock
  attr_reader :counter
  def initialize
    @counter = 0
  end

  def clock_gettime(*args)
    counter += 1
  end
end