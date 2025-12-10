# frozen_string_literal: true

require 'vips'
require 'fileutils'

module Naiso
  # 이미지 분할기
  class ImageSplitter
    def initialize(config = nil)
      @config = config || SplitConfig.new
    end

    def split(image_path, output_dir: nil, verbose: true)
      result = SplitResult.new

      # 이미지 로드
      image = Vips::Image.new_from_file(image_path)

      # 설정값 계산
      min_height = @config.min_section_height || (image.width * 2 / 3)
      max_height = @config.max_section_height || (image.width * 1.5).to_i

      if verbose
        puts "이미지 크기: #{image.width} x #{image.height}"
        puts "최소 섹션 높이: #{min_height}px"
        puts "최대 섹션 높이: #{max_height}px"
      end

      # 분석기 및 감지기 초기화
      analyzer = RowAnalyzer.new(image)
      detector = SplitPointDetector.new(analyzer, @config)

      # 분할점 수집
      result.uniform_regions = detector.find_uniform_regions
      result.divider_lines = detector.find_divider_lines
      result.background_transitions = detector.find_background_transitions

      print_detection_results(result) if verbose

      # 분할점 병합
      split_points = merge_split_points(result, image.height, min_height)

      # 최대 높이 초과 섹션 분할
      if max_height > 0
        split_points, complexity_splits = apply_max_height_splits(
          split_points, max_height, min_height, detector, verbose
        )
        result.complexity_splits = complexity_splits
      end

      result.split_points = split_points

      if verbose
        puts "\n분할 위치: #{split_points}"
        puts "생성될 섹션 수: #{split_points.size - 1}개"
      end

      # 이미지 분할 및 저장
      if split_points.nil? || split_points.size < 2
        puts '분할할 영역을 찾지 못했습니다.' if verbose
        return result
      end

      output_dir = prepare_output_dir(image_path, output_dir)
      result.output_files = save_sections(image, split_points, output_dir, image_path, verbose)

      result
    end

    private

    def merge_split_points(result, image_height, min_height)
      split_y = [0]

      # 단색 영역 중앙점 추가
      result.uniform_regions.each do |start_pos, end_pos|
        split_y << (start_pos + end_pos) / 2
      end

      # 구분선 추가
      split_y.concat(result.divider_lines)

      # 배경색 전환점 추가
      split_y.concat(result.background_transitions)

      split_y << image_height

      # 정렬 및 중복 제거
      split_y = split_y.uniq.sort

      # 너무 작은 섹션 병합 (단, 시작점 0은 항상 유지)
      filtered = [0]
      split_y[1..].each do |y|
        gap = y - filtered.last
        if gap >= min_height
          filtered << y
        elsif filtered.size >= 2
          new_prev_gap = y - filtered[-2]
          filtered[-1] = y if new_prev_gap >= min_height
        elsif filtered.last != 0
          # 시작점이 0이면 유지, 아니면 대체
          filtered[-1] = y
        end
        # filtered.last가 0이고 gap < min_height면, 다음 분할점을 기다림
      end

      filtered << image_height if filtered.last != image_height

      filtered
    end

    def apply_max_height_splits(split_points, max_height, min_height, detector, verbose)
      needs_split = (0...(split_points.size - 1)).any? do |i|
        split_points[i + 1] - split_points[i] > max_height
      end

      return [split_points, []] unless needs_split

      puts "\n최대 높이 초과 섹션 감지, 복잡도 기반 분할 수행..." if verbose

      complexity_splits = []
      final_splits = [split_points.first]

      (0...(split_points.size - 1)).each do |i|
        section_start = split_points[i]
        section_end = split_points[i + 1]
        section_height = section_end - section_start

        if section_height > max_height
          current_start = section_start

          while current_start < section_end
            remaining = section_end - current_start
            break if remaining <= max_height

            search_start = current_start + min_height
            search_end = [current_start + max_height, section_end - min_height].min

            best_split = if search_start >= search_end
                           (current_start + [current_start + max_height, section_end].min) / 2
                         else
                           margin = [50, (search_end - search_start) / 4].min
                           detector.find_best_split_in_range(search_start, search_end, margin: margin)
                         end

            final_splits << best_split
            complexity_splits << best_split

            puts "  복잡도 기반 분할: 행 #{best_split}" if verbose

            current_start = best_split
          end
        end

        final_splits << section_end
      end

      [final_splits.uniq.sort, complexity_splits]
    end

    def prepare_output_dir(image_path, output_dir)
      output_dir ||= File.join(File.dirname(image_path), 'sections')
      FileUtils.mkdir_p(output_dir)
      output_dir
    end

    def save_sections(image, split_points, output_dir, image_path, verbose)
      output_files = []
      base_name = File.basename(image_path, '.*')

      (0...(split_points.size - 1)).each do |i|
        y_start = split_points[i]
        y_end = split_points[i + 1]
        height = y_end - y_start

        # 섹션 추출
        section = image.crop(0, y_start, image.width, height)

        # 저장
        output_path = File.join(output_dir, "#{base_name}_section_#{format('%02d', i + 1)}.jpg")
        section.write_to_file(output_path, Q: 95)
        output_files << output_path

        puts "  저장: #{File.basename(output_path)} (높이: #{height}px)" if verbose
      end

      output_files
    end

    def print_detection_results(result)
      puts "\n발견된 단색 영역: #{result.uniform_regions.size}개"
      result.uniform_regions.each_with_index do |(start_pos, end_pos), i|
        puts "  #{i + 1}. 행 #{start_pos} ~ #{end_pos} (높이: #{end_pos - start_pos}px)"
      end

      puts "\n발견된 구분선: #{result.divider_lines.size}개"
      result.divider_lines.each_with_index do |y, i|
        puts "  #{i + 1}. 행 #{y}"
      end

      puts "\n발견된 배경색 전환: #{result.background_transitions.size}개"
      result.background_transitions.each_with_index do |y, i|
        puts "  #{i + 1}. 행 #{y}"
      end
    end
  end
end
