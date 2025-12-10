# frozen_string_literal: true

require 'numo/narray'

module Naiso
  # 분할점 감지기
  class SplitPointDetector
    def initialize(analyzer, config)
      @analyzer = analyzer
      @config = config
    end

    # 연속된 단색 영역 찾기
    def find_uniform_regions
      variance = @analyzer.variance
      threshold = @config.variance_threshold

      regions = []
      in_region = false
      region_start = 0

      @analyzer.height.times do |i|
        uniform = variance[i] < threshold

        if uniform && !in_region
          in_region = true
          region_start = i
        elsif !uniform && in_region
          in_region = false
          if i - region_start >= @config.min_gap_height
            regions << [region_start, i]
          end
        end
      end

      # 마지막까지 단색이면
      if in_region
        region_end = @analyzer.height
        if region_end - region_start >= @config.min_gap_height
          regions << [region_start, region_end]
        end
      end

      regions
    end

    # 가로 구분선 감지
    def find_divider_lines(
      line_variance_threshold: 3.0,
      margin_check: 30,
      margin_variance_threshold: 5.0
    )
      img_array = @analyzer.img_array
      variance = @analyzer.variance
      height = @analyzer.height

      dividers = []

      (margin_check...(height - margin_check)).each do |y|
        next if variance[y] > line_variance_threshold

        margin_above = img_array[(y - margin_check)...y, true, true]
        margin_below = img_array[(y + 1)...(y + 1 + margin_check), true, true]

        above_variance = calculate_region_variance(margin_above)
        below_variance = calculate_region_variance(margin_below)

        next if above_variance > margin_variance_threshold
        next if below_variance > margin_variance_threshold

        above_mean = margin_above.cast_to(Numo::DFloat).mean
        below_mean = margin_below.cast_to(Numo::DFloat).mean
        line_mean = img_array[y, true, true].cast_to(Numo::DFloat).mean

        color_diff = (line_mean - (above_mean + below_mean) / 2.0).abs
        dividers << y if color_diff > 10
      end

      merge_nearby_points(dividers)
    end

    # 배경색 전환 지점 감지
    def find_background_transitions(
      variance_threshold: 5.0,
      min_uniform_height: 20,
      color_diff_threshold: 15.0
    )
      img_array = @analyzer.img_array
      variance = @analyzer.variance
      height = @analyzer.height

      transitions = []

      (min_uniform_height...(height - min_uniform_height)).each do |y|
        # 위아래가 모두 단색인지 확인
        above_uniform = variance[(y - min_uniform_height)...y].to_a.all? { |v| v < variance_threshold }
        below_uniform = variance[y...(y + min_uniform_height)].to_a.all? { |v| v < variance_threshold }

        next unless above_uniform && below_uniform

        above_region = img_array[(y - min_uniform_height)...y, true, true]
        below_region = img_array[y...(y + min_uniform_height), true, true]

        above_color = calculate_mean_color(above_region)
        below_color = calculate_mean_color(below_region)

        # RGB 유클리드 거리
        color_diff = Math.sqrt(
          above_color.zip(below_color).map { |a, b| (a - b) ** 2 }.sum
        )

        transitions << y if color_diff > color_diff_threshold
      end

      merge_nearby_points(transitions)
    end

    # 주어진 범위 내에서 복잡도가 가장 낮은 분할점 찾기
    def find_best_split_in_range(start_pos, end_pos, margin: 50)
      search_start = start_pos + margin
      search_end = end_pos - margin

      return (start_pos + end_pos) / 2 if search_start >= search_end

      window_size = 20
      complexity = @analyzer.complexity

      region = complexity[search_start...search_end]
      return search_start + region.min_index if region.size < window_size

      # 이동 평균으로 smoothing
      smoothed = []
      (0...(region.size - window_size)).each do |i|
        smoothed << region[i...(i + window_size)].mean
      end

      best_idx = smoothed.each_with_index.min_by { |v, _| v }[1] + window_size / 2
      search_start + best_idx
    end

    private

    def calculate_region_variance(region)
      # 각 행의 표준편차 평균
      variances = []
      region.shape[0].times do |y|
        row = region[y, true, true].cast_to(Numo::DFloat)
        channel_stds = (0...region.shape[2]).map do |c|
          channel_data = row[true, c]
          mean = channel_data.mean
          Math.sqrt(((channel_data - mean) ** 2).mean)
        end
        variances << channel_stds.sum / channel_stds.size
      end
      variances.sum / variances.size
    end

    def calculate_mean_color(region)
      channels = region.shape[2]
      (0...channels).map do |c|
        region[true, true, c].cast_to(Numo::DFloat).mean
      end
    end

    def merge_nearby_points(points, threshold: 5)
      return [] if points.empty?

      merged = []
      group_start = points.first
      group_end = points.first

      points[1..].each do |y|
        if y <= group_end + threshold
          group_end = y
        else
          merged << (group_start + group_end) / 2
          group_start = y
          group_end = y
        end
      end

      merged << (group_start + group_end) / 2
      merged
    end
  end
end
