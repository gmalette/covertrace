require "covertrace"

RSpec.configure do |config|
  config.around(:each) do |example|
    Covertrace.tracer.trace(name: example.full_description, &example)
  end

  config.after(:suite) do
    Covertrace.call_after_suite
  end
end
