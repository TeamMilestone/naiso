# frozen_string_literal: true

module Naiso
  # 분할 설정
  class SplitConfig
    attr_accessor :variance_threshold, :min_gap_height, :min_section_height, :max_section_height

    def initialize(
      variance_threshold: 10.0,
      min_gap_height: 50,
      min_section_height: nil,
      max_section_height: nil
    )
      @variance_threshold = variance_threshold
      @min_gap_height = min_gap_height
      @min_section_height = min_section_height
      @max_section_height = max_section_height
    end
  end
end
