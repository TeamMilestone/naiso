# frozen_string_literal: true

module Naiso
  # 분할 결과
  class SplitResult
    attr_accessor :output_files, :split_points, :uniform_regions,
                  :divider_lines, :background_transitions, :complexity_splits

    def initialize
      @output_files = []
      @split_points = []
      @uniform_regions = []
      @divider_lines = []
      @background_transitions = []
      @complexity_splits = []
    end
  end
end
