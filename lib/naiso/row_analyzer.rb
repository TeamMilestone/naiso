# frozen_string_literal: true

require 'vips'
require 'numo/narray'

module Naiso
  # 이미지 행 분석기
  class RowAnalyzer
    attr_reader :height, :width

    def initialize(image)
      @image = image
      @width = image.width
      @height = image.height
      @variance = nil
      @complexity = nil
      @img_array = nil
    end

    # 이미지를 Numo::NArray로 변환 (지연 로딩)
    def img_array
      @img_array ||= begin
        # Vips 이미지를 메모리 배열로 변환
        bands = @image.bands
        data = @image.write_to_memory

        # 바이트 배열을 NArray로 변환
        arr = Numo::UInt8.from_binary(data)
        arr.reshape(@height, @width, bands)
      end
    end

    # 각 행의 색상 분산 (지연 계산)
    def variance
      @variance ||= calculate_variance
    end

    # 각 행의 콘텐츠 복잡도 (지연 계산)
    def complexity
      @complexity ||= calculate_complexity
    end

    private

    def calculate_variance
      arr = img_array
      result = Numo::DFloat.zeros(@height)

      @height.times do |y|
        row = arr[y, true, true].cast_to(Numo::DFloat)
        # 각 채널별 표준편차 계산 후 평균
        channel_stds = (0...arr.shape[2]).map do |c|
          channel_data = row[true, c]
          std_dev(channel_data)
        end
        result[y] = channel_stds.sum / channel_stds.size
      end

      result
    end

    def calculate_complexity
      # Sobel 엣지 감지
      gray = @image.colourspace(:b_w)
      edges = gray.sobel

      # 엣지 이미지를 배열로 변환
      edge_data = edges.write_to_memory
      edge_arr = Numo::UInt8.from_binary(edge_data).reshape(@height, @width)

      # 각 행의 엣지 밀도
      edge_density = Numo::DFloat.zeros(@height)
      @height.times do |y|
        edge_density[y] = edge_arr[y, true].cast_to(Numo::DFloat).mean
      end

      # 색상 분산
      color_variance = variance

      # 정규화
      edge_max = edge_density.max
      color_max = color_variance.max

      edge_norm = edge_max > 0 ? edge_density / edge_max : edge_density
      color_norm = color_max > 0 ? color_variance / color_max : color_variance

      # 가중 합산
      edge_norm * 0.7 + color_norm * 0.3
    end

    def std_dev(arr)
      mean = arr.mean
      variance = ((arr - mean) ** 2).mean
      Math.sqrt(variance)
    end
  end
end
