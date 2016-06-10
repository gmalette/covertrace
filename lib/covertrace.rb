require "coverage"
require "covertrace/version"
require "unified_diff"
require "open3"

module Covertrace
  extend self

  def start(**options)
    Coverage.start
    @tracer = Tracer.new(config: Config.new(**options))
  end

  attr_reader :after_suite_callbacks

  @after_suite_callbacks = []

  def after_suite(&block)
    @after_suite_callbacks << block
  end

  def call_after_suite
    @after_suite_callbacks.each { |callback| callback.call(tracer.dependencies) }
  end

  def tracer
    raise "Coverage.start hasn't been called" unless @tracer
    @tracer
  end

  def trace(name:, &block)
    tracer.trace(name: name, &block)
  end

  AlreadyStartedError = Class.new(StandardError)

  Config = Struct.new(:filter_proc, :file_mapper_proc) do
    def initialize(root:, filter: nil, file_mapper: nil)
      @root = Pathname.new(File.join(Pathname.new(root).realpath, ""))

      self.filter_proc = filter || default_filter
      self.file_mapper_proc = file_mapper || default_file_mapper
    end

    def default_filter
      root = @root.to_s
      ignored = %w(spec test vendor).map do |dir|
        dir = @root.join("#{dir}/")
        next unless dir.exist?
        dir.to_s
      end.compact
      lambda do |path|
        path.to_s.start_with?(root) && ignored.none? { |dir| path.to_s.start_with?(dir) }
      end
    end

    def default_file_mapper
      lambda do |path|
        path.to_s.sub(@root.to_s, "")
      end
    end

    def filter(file_name)
      filter_proc.call(file_name)
    end

    def map_file_name(file_name)
      file_mapper_proc.call(file_name)
    end
  end

  Tracer = Struct.new(:config) do
    def initialize(config:)
      self.config = config.dup
      @result_set = ResultSet.new
    end

    def trace(name:, &block)
      value = nil
      results = coverage_tracking do
        value = block.call
      end

      results = results.map do |file_name, coverage|
        next unless config.filter(file_name)
        [config.map_file_name(file_name), coverage]
      end.compact.to_h

      @result_set.record(name, Result.new(results))
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

    private

    def coverage_tracking(&block)
      Coverage.start
      state_before = Coverage.peek_result
      block.call
      state_after = Coverage.peek_result
      filtered = state_after.map do |file_name, coverage_after|
        coverage_before = state_before.fetch(file_name, [])
        next [file_name, coverage_after.map { nil }] if coverage_after == coverage_before
        diffs = coverage_after.zip(coverage_before).map do |after, before|
          next if after.nil?
          after.to_i - before.to_i
        end
        [file_name, diffs]
      end
      filtered.to_h
    end
  end

  Dependencies = Struct.new(:hash) do
    def self.from_h(hash)
      new(hash: hash)
    end

    def initialize(hash:)
      self.hash = hash
    end

    def merge(other)
      new_hash = (hash.keys + other.hash.keys).map do |key|
        lines = hash.fetch(key, [])
        other_lines = other.hash.fetch(key, [])
        tests = (0...([lines.length, other_lines.length].max)).map do |line_number|
          (lines.fetch(line_number, []) + other_lines.fetch(line_number, [])).uniq
        end
        [key, tests]
      end.to_h
      Dependencies.new(hash: new_hash)
    end

    def names(file:, line_range:)
      hash
        .fetch(file, [])
        .drop(line_range.begin)
        .take(line_range.size)
        .flatten
        .uniq
    end

    def to_json
      hash.to_json
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

  class GitDiffer
    def changes(merge_base:)
      base_commit, _status = Open3.capture2("git", "merge-base", merge_base, "HEAD")
      patches, _status = Open3.capture2("git", "diff", "--unified=0", base_commit.strip)
      patches
        .split(/^diff.*?$\nindex.*?$/m)
        .reject(&:empty?)
        .map(&:strip)
        .map { |diff_content| UnifiedDiff.parse(diff_content) }
        .map do |diff|
          diff.chunks.map do |chunk|
            file = diff.original_file.split("/", 2).last
            original_range = bound_range(chunk.original_range)
            modified_range = bound_range(chunk.modified_range)
            [file, { original_range: original_range, modified_range: modified_range }]
          end.compact
        end
        .flatten(1)
        .to_h
    end

    private

    def bound_range(range)
      Range.new([range.begin - 1, 0].max, [range.end - 1, 0].max, range.exclude_end?)
    end
  end
end
