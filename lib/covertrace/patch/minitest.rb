require "covertrace"

module Covertrace::Minitest
  def run_one_method(klass, method_name, reporter)
    Covertrace.tracer.trace(name: "#{klass}##{method_name}") do
      super
    end
  end
end

class Minitest::Runnable
  class << self
    prepend Covertrace::Minitest
  end
end

class Covertrace::Reporter < Minitest::AbstractReporter
  def report
    Covertrace.call_after_suite
  end
end

Minitest.reporter << Covertrace::Reporter.new
