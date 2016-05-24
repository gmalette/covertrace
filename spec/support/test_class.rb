class TestClass
  def initialize(x)
    @x = x
    do_more_initialize
  end

  def do_more_initialize
    @y = 1
  end

  def toto
    tutu
  end

  private

  def tutu
    @x = 2
  end
end
