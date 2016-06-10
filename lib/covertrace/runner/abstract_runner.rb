module Covertrace
  module Runner
    class AbstractRunner
      def initialize(dependencies:, merge_base: "origin/master", root: ".")
        @dependencies = dependencies
        @merge_base = merge_base
        @root = root
      end

      def run
      end
    end
  end
end
