# frozen_string_literal: true

require 'vips'

module Naiso
  # 이미지 병합기
  class ImageMerger
    # 여러 이미지를 세로로 합치기
    # @param image_paths [Array<String>] 이미지 파일 경로 배열 (순서대로 합쳐짐)
    # @param output_path [String] 출력 파일 경로
    # @param verbose [Boolean] 상세 출력 여부
    # @return [String] 출력 파일 경로
    def self.merge(image_paths, output_path, verbose: true)
      raise ArgumentError, '이미지가 없습니다' if image_paths.empty?

      puts "이미지 병합 중... (#{image_paths.size}개)" if verbose

      # 첫 번째 이미지 로드
      images = image_paths.map { |path| Vips::Image.new_from_file(path) }

      # 너비 확인 (모두 같아야 함)
      widths = images.map(&:width).uniq
      if widths.size > 1
        puts "경고: 이미지 너비가 다릅니다 (#{widths.join(', ')}px). 첫 번째 이미지 너비로 맞춥니다." if verbose
        target_width = images.first.width
        images = images.map do |img|
          img.width == target_width ? img : img.resize(target_width.to_f / img.width)
        end
      end

      # 세로로 합치기
      merged = images.first
      images[1..].each do |img|
        merged = merged.join(img, :vertical)
      end

      # 저장
      merged.write_to_file(output_path, Q: 95)

      if verbose
        total_height = images.sum(&:height)
        puts "  입력: #{image_paths.size}개 이미지"
        puts "  출력: #{output_path}"
        puts "  크기: #{merged.width} x #{merged.height}px"
      end

      output_path
    end

    # 디렉토리 내 섹션 이미지들을 합치기
    # @param input_dir [String] 섹션 이미지가 있는 디렉토리
    # @param output_path [String] 출력 파일 경로 (nil이면 자동 생성)
    # @param pattern [String] 파일 패턴 (glob)
    # @param verbose [Boolean] 상세 출력 여부
    # @return [String] 출력 파일 경로
    def self.merge_sections(input_dir, output_path: nil, pattern: '*_section_*.jpg', verbose: true)
      # 섹션 파일 찾기 (정렬)
      section_files = Dir.glob(File.join(input_dir, pattern)).sort

      raise ArgumentError, "섹션 파일을 찾을 수 없습니다: #{input_dir}/#{pattern}" if section_files.empty?

      # 출력 경로 자동 생성
      if output_path.nil?
        # 첫 번째 파일에서 기본 이름 추출: "vitac_section_01.jpg" -> "vitac"
        base_name = File.basename(section_files.first).sub(/_section_\d+\.jpg$/, '')
        output_path = File.join(input_dir, "#{base_name}_merged.jpg")
      end

      merge(section_files, output_path, verbose: verbose)
    end
  end
end
