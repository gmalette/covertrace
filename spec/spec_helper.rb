$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'covertrace'

module CoverageHelper
  private

  def test_class_file_path
    File.expand_path("support/test_class.rb", File.dirname(__FILE__))
  end

  def test_class_coverage
    [
      1, 1, 1, 1, nil, nil, 1, 1, nil, nil, 1, 0, nil, nil, nil, nil, 1, 0, nil, nil,
    ]
  end

  def mock_coverage_results
    expect(Coverage).to receive(:start)
    expect(Coverage).to receive(:peek_result).and_return(
      {},
      {
        test_class_file_path => test_class_coverage,
      },
    )
  end
end
