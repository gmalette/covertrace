require "spec_helper"
require "pry"

describe Covertrace do
  include CoverageHelper

  let(:config) { Covertrace::Config.new }

  it 'has a version number' do
    expect(Covertrace::VERSION).not_to be nil
  end
end

describe Covertrace::Tracer do
  include CoverageHelper

  let(:config) { Covertrace::Config.new }
  subject { described_class.new(config: config) }

  describe "#trace" do
    it "returns the value of the expression" do
      mock_coverage_results
      expect(subject.trace(name: "toto") { "tutu" }).to eq("tutu")
    end

    it "records an empty array if nothing_changed" do
      mock_empty_coverage_results
      expect_any_instance_of(Covertrace::ResultSet).to receive(:record).with(
        "toto",
        instance_of(Covertrace::Result)
      ) do |_self, _name, result|
        expect(result.coverage.values.flatten).to all(be_nil)
      end
      subject.trace(name: "toto") { "tutu" }
    end

    it "records coverage results" do
      mock_coverage_results
      expect_any_instance_of(Covertrace::ResultSet).to receive(:record).with(
        "toto",
        instance_of(Covertrace::Result)
      ) do |_self, _name, result|
        expect(result.coverage.values.flatten).to satisfy { |values| values.any? { |v| v > 0 } }
      end
      subject.trace(name: "toto") { "tutu" }
    end

    it "yields control" do
      expect{ |b| subject.trace(name: "toto", &b) }.to yield_control
    end
  end

  describe "#dependencies" do
    before do
      mock_coverage_results
      subject.trace(name: "toto"){}
    end

    context "without filtering" do
      it "doesn't filter results" do
        expect(subject.dependencies).to eq(
          Covertrace::Dependencies.new(
            hash: {
              test_class_file_path => test_class_coverage.map.with_index do |coverage, index|
                next [] unless coverage.to_i > 0
                ["toto"]
              end,
            },
          )
        )
      end
    end

    context "with filtering" do
      let(:config) { Covertrace::Config.new(filter: ->(file){ false }) }

      it "filters the results in the result_set" do
        expect(subject.dependencies).to eq(
          Covertrace::Dependencies.new(
            hash: {},
          )
        )
      end
    end

    context "with mapping" do
      let(:config) { Covertrace::Config.new(file_mapper: ->(file) { "a" }) }

      it "maps file names" do
        expect(subject.dependencies).to eq(
          Covertrace::Dependencies.new(
            hash: {
              "a" => test_class_coverage.map.with_index do |coverage, index|
                next [] unless coverage.to_i > 0
                ["toto"]
              end,
            },
          )
        )
      end
    end
  end
end

describe Covertrace::Dependencies do
  include CoverageHelper

  subject do
    described_class.new(
      hash: {
        test_class_file_path => test_class_coverage.map do |coverage|
          next [] unless coverage.to_i > 0
          ["toto"]
        end,
      },
    )
  end

  describe "#names" do
    it "returns names affected by the lines" do
      expect(subject.names(file: test_class_file_path, line_range: (0..3))).to eq(["toto"])
    end

    it "returns an empty array if no names are affected" do
      expect(subject.names(file: test_class_file_path, line_range: (4..5))).to eq([])
      expect(subject.names(file: "unexisting file", line_range: (0..3))).to eq([])
    end
  end

  describe "#merge" do
    it "merges with dependency and returns a new object" do
      other = described_class.new(
        hash: {
          "a.rb" => [
            [],
            ["titi"],
          ],
          test_class_file_path => test_class_coverage.map { ["titi"] },
        }
      )
      expected_for_test_class = test_class_coverage.map do |coverage|
        result = []
        result << "toto" if coverage.to_i > 0
        result << "titi"
        result
      end
      expect(subject.merge(other)).to eq(
        described_class.new(
          hash: {
            test_class_file_path => expected_for_test_class,
            "a.rb" => [[], ["titi"]],
          }
        )
      )
    end
  end
end

describe Covertrace::GitDiffer do
  subject { Covertrace::GitDiffer.new(root: ".") }

  describe "#changes" do
    before do
      allow(Open3).to receive(:capture2)
        .with("git", "merge-base", "origin/master", "HEAD")
        .and_return(["SHA", success])
      allow(Open3).to receive(:capture2)
        .with("git", "diff", "--unified=0", "SHA")
        .and_return([patch, success])
    end

    let(:success) { double("Process::Status", success?: true) }

    let(:patch) do
      <<-PATCH
diff --git a/covertrace.gemspec b/covertrace.gemspec
index 78389d4..069c282 100644
--- a/covertrace.gemspec
+++ b/covertrace.gemspec
@@ -29,0 +30,2 @@ Gem::Specification.new do |spec|
+  spec.add_dependency "unified_diff", "~> 0.3"
+
diff --git a/lib/covertrace.rb b/lib/covertrace.rb
index e8e7e32..a76bcae 100644
--- a/lib/covertrace.rb
+++ b/lib/covertrace.rb
@@ -2,0 +3 @@ require "covertrace/version"
+require "unified_diff"
@@ -108,0 +110,3 @@ module Covertrace
+
+  class GitDiff
+  end
diff --git a/spec/covertrace_spec.rb b/spec/covertrace_spec.rb
index 5cdd69f..9a9aad4 100644
--- a/spec/covertrace_spec.rb
+++ b/spec/covertrace_spec.rb
@@ -112,0 +113,3 @@ end
+
+describe Covertrace::GitDiff do
+end
      PATCH
    end

    it "returns an array of changes where line indices start at 0" do
      diffs = subject.changes(merge_base: "origin/master")
      expect(diffs).to eq(
        "covertrace.gemspec" => {
          original_range: (28...28),
          modified_range: (29...31),
        },
        "lib/covertrace.rb" => {
          original_range: (107...107),
          modified_range: (109...112),
        },
        "spec/covertrace_spec.rb" => {
          original_range: (111...111),
          modified_range: (112...115),
        },
      )
    end
  end

  describe "#filter" do
    it "returns a lambda that filters out paths not under the root" do
      expect(subject.filter.call("/var/log/toto.rb")).to eq(false)
      expect(subject.filter.call(Pathname.new(".").join("spec").realpath)).to eq(true)
    end
  end

  describe "#file_mapper" do
    it "returns a lambda that removes the root from the path" do
      expect(subject.file_mapper.call(Pathname.new(".").join("spec").realpath)).to eq("spec")
    end
  end
end
