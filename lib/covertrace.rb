require "covertrace/version"

module Covertrace
  AlreadyStartedError = Class.new(StandardError)

  Config = Struct.new(:filter_proc) do
    def initialize(filter: ->(_){ true })
      self.filter_proc = filter
    end

    def filter(results)
      results.select do |(file_name, _coverage)|
        filter_proc.call(file_name)
      end
    end
  end

  Tracer = Struct.new(:config) do
    def initialize(config:)
      @config = config.dup
      @result_set = ResultSet.new
    end

    def trace(name:, &block)
      value = nil
      results = Covertrace.trace do
        value = block.call
      end
      results = Result.new(@config.filter(results))
      @result_set.record(name, results)
      value
    end

    def dependencies
      Dependencies.from_h(
        @result_set.results.each_with_object(Hash.new{|h,k| h[k] = []}) do |(name, result), h|
          result.coverage.each do |file_name, coverage|
            h[file_name] ||= []
            coverage.each_with_index do |cov, index|
              h[file_name][index] ||= []
              next unless cov.to_i >= 1
              h[file_name][index] << name
            end
          end
        end
      )
    end
  end

  Dependencies = Struct.new(:hash) do
    def self.from_h(hash)
      new(hash: hash)
    end

    def initialize(hash:)
      self.hash = hash
    end

    def names(file:, line_range:)
      hash.fetch(file, []).slice(line_range).flatten.uniq
    end
  end

  ResultSet = Struct.new(:results) do
    def initialize
      self.results = {}
    end

    def record(name, result)
      self.results[name] = result
    end
  end

  Result = Struct.new(:coverage) do
    def initialize(coverage)
      self.coverage = coverage
    end

    def empty?
      coverage.empty?
    end
  end

  def self.trace(&block)
    require "coverage"
    raise AlreadyStartedError, "Covertrace already tracing" if @started
    @started = true
    Coverage.start
    yield
    Coverage.result
  ensure
    @started = false
  end
end
