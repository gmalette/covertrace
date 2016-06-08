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
  end
end

describe Covertrace::Dependencies do
  include CoverageHelper

  subject do
    described_class.new(
      hash: {
        test_class_file_path => test_class_coverage.map.with_index do |coverage, index|
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
end
