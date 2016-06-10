require "covertrace"

module Covertrace
  module Runner
    class RSpec < AbstractRunner
      def run
        ARGV.clear
        ARGV.push(".", *tests_to_run.flat_map { |test| ["--example", test] })

        load Gem.bin_path("rspec-core", "rspec")
      end

      private

      attr_reader(
        :dependencies,
        :merge_base,
        :root,
      )

      def tests_to_run
        changes = Covertrace::GitChanges.changes(merge_base: merge_base, root: root)
        changes.map do |file_change|
          next [] if file_change.old_line_range.nil?
          dependencies.names(file: file_change.old_file_name, line_range: file_change.old_line_range)
        end.flatten
      end
    end
  end
end
