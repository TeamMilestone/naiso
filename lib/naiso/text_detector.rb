# frozen_string_literal: true

require 'vips'
require 'rtesseract'
require 'json'

module Naiso
  # 텍스트 검출기
  class TextDetector
    # 최소 텍스트 길이 (공백 제외)
    MIN_TEXT_LENGTH = 3
    # 최소 신뢰도 (0-100, 이 값 미만은 무시)
    MIN_CONFIDENCE = 60.0
    # 최소 단어 크기 (픽셀, 이 값 미만은 노이즈로 간주)
    MIN_WORD_SIZE = 10

    def initialize(languages: %w[kor eng], min_confidence: MIN_CONFIDENCE, min_word_size: MIN_WORD_SIZE)
      @languages = languages.join('+')
      @min_confidence = min_confidence
      @min_word_size = min_word_size
    end

    # 이미지에 텍스트가 있는지 검사
    # 원본과 반전 이미지 모두에서 OCR 시도 (흰색 텍스트 대응)
    # @param image_path [String] 이미지 파일 경로
    # @return [Hash] { has_text: Boolean, text: String, text_length: Integer }
    def detect(image_path)
      # 원본 이미지에서 OCR
      original_result = ocr_image(image_path)

      # 원본에서 텍스트를 찾았으면 반환
      return original_result if original_result[:has_text]

      # 반전 이미지에서 OCR 시도 (흰색 텍스트 + 어두운 배경 대응)
      inverted_result = ocr_inverted_image(image_path)

      # 더 많은 텍스트를 찾은 결과 반환
      if inverted_result[:text_length] > original_result[:text_length]
        inverted_result
      else
        original_result
      end
    rescue StandardError => e
      {
        has_text: false,
        text: '',
        text_length: 0,
        error: e.message
      }
    end

    # 텍스트 크기 정보를 포함한 상세 검출
    # @param image_path [String] 이미지 파일 경로
    # @return [Hash] { has_text:, text:, text_length:, words: [{text:, x:, y:, width:, height:, conf:}], stats: {min_height:, max_height:, avg_height:} }
    def detect_with_size(image_path)
      result = detect_tsv(image_path)

      # 원본에서 못 찾으면 반전 이미지 시도
      unless result[:has_text]
        inverted_result = detect_tsv_inverted(image_path)
        result = inverted_result if inverted_result[:text_length] > result[:text_length]
      end

      result
    rescue StandardError => e
      {
        has_text: false,
        text: '',
        text_length: 0,
        words: [],
        stats: nil,
        error: e.message
      }
    end

    # 여러 이미지에서 텍스트 분석 (크기 정보 포함)
    # @param image_paths [Array<String>] 이미지 파일 경로 배열
    # @param verbose [Boolean] 상세 출력 여부
    # @param json_path [String, nil] JSON 저장 경로 (nil이면 저장 안함)
    # @return [Array<Hash>] 분석 결과 배열
    def analyze_images(image_paths, verbose: true, json_path: nil)
      puts "\n텍스트 검출 중..." if verbose

      results = []

      image_paths.each_with_index do |path, i|
        result = detect_with_size(path)
        filename = File.basename(path)

        analysis = {
          filename: filename,
          path: path,
          has_text: result[:has_text],
          text_length: result[:text_length],
          text: result[:text],
          stats: result[:stats],
          words: result[:words]
        }
        results << analysis

        if verbose
          if result[:has_text] && result[:stats]
            stats = result[:stats]
            puts format('  %2d. %-30s 텍스트 있음 (%d자, %d단어) | 높이: %d~%dpx (평균 %.1fpx)',
                        i + 1, filename, result[:text_length], stats[:word_count],
                        stats[:min_height], stats[:max_height], stats[:avg_height])
          else
            puts format('  %2d. %-30s 텍스트 없음', i + 1, filename)
          end
        end
      end

      # JSON 저장
      if json_path
        save_json(results, json_path)
        puts "\nJSON 저장: #{json_path}" if verbose
      end

      # 텍스트 없는 이미지 요약
      no_text_images = results.reject { |r| r[:has_text] }
      if verbose
        puts "\n텍스트 없는 이미지: #{no_text_images.size}개"
        no_text_images.each do |r|
          puts "  - #{r[:filename]}"
        end
      end

      results
    end

    # 여러 이미지에서 텍스트 없는 이미지 찾기 (하위 호환성)
    # @param image_paths [Array<String>] 이미지 파일 경로 배열
    # @param verbose [Boolean] 상세 출력 여부
    # @return [Array<String>] 텍스트가 없는 이미지 경로 배열
    def find_images_without_text(image_paths, verbose: true)
      results = analyze_images(image_paths, verbose: verbose)
      results.reject { |r| r[:has_text] }.map { |r| r[:path] }
    end

    private

    def ocr_image(image_path)
      # PSM 3 (기본값: 자동 페이지 세분화)로 시도
      result = ocr_with_psm(image_path, 3)
      return result if result[:has_text]

      # PSM 6 (단일 텍스트 블록 가정)으로 재시도
      ocr_with_psm(image_path, 6)
    end

    def ocr_with_psm(image_path, psm)
      ocr = RTesseract.new(image_path, lang: @languages, psm: psm)
      text = ocr.to_s.strip
      clean_text = text.gsub(/[\s\p{P}\p{S}]/, '')

      {
        has_text: clean_text.length >= MIN_TEXT_LENGTH,
        text: text,
        text_length: clean_text.length
      }
    end

    def ocr_inverted_image(image_path)
      # libvips로 이미지 반전
      image = Vips::Image.new_from_file(image_path)
      inverted = image.invert

      # 임시 파일로 저장
      temp_path = "/tmp/inverted_#{File.basename(image_path)}"
      inverted.write_to_file(temp_path)

      result = ocr_image(temp_path)

      # 임시 파일 삭제
      File.delete(temp_path) if File.exist?(temp_path)

      result
    end

    # TSV 출력으로 텍스트 크기 정보 추출
    def detect_tsv(image_path)
      parse_tsv_output(image_path, image_path)
    end

    def detect_tsv_inverted(image_path)
      image = Vips::Image.new_from_file(image_path)
      inverted = image.invert

      temp_path = "/tmp/inverted_#{File.basename(image_path)}"
      inverted.write_to_file(temp_path)

      result = parse_tsv_output(temp_path, image_path)

      File.delete(temp_path) if File.exist?(temp_path)

      result
    end

    def parse_tsv_output(ocr_path, original_path)
      # PSM 6으로 TSV 출력
      tsv_output = `tesseract "#{ocr_path}" stdout -l #{@languages} --psm 6 tsv 2>/dev/null`

      all_words = []
      lines = tsv_output.split("\n")

      # 헤더 스킵
      lines[1..].each do |line|
        cols = line.split("\t")
        next if cols.size < 12

        level = cols[0].to_i
        next unless level == 5 # word level

        text = cols[11].to_s.strip
        next if text.empty?

        conf = cols[10].to_f
        next if conf < 0 # 빈 결과 제외

        all_words << {
          text: text,
          x: cols[6].to_i,
          y: cols[7].to_i,
          width: cols[8].to_i,
          height: cols[9].to_i,
          conf: conf.round(1)
        }
      end

      # 신뢰도 및 크기 필터링
      confident_words = all_words.select do |w|
        w[:conf] >= @min_confidence &&
          w[:width] >= @min_word_size &&
          w[:height] >= @min_word_size
      end

      # 신뢰도 높은 단어들로 텍스트 합치기
      full_text = confident_words.map { |w| w[:text] }.join(' ')
      clean_text = full_text.gsub(/[\s\p{P}\p{S}]/, '')

      # 통계 계산 (신뢰도 높은 단어 기준)
      stats = nil
      if confident_words.any?
        heights = confident_words.map { |w| w[:height] }
        stats = {
          min_height: heights.min,
          max_height: heights.max,
          avg_height: (heights.sum.to_f / heights.size).round(1),
          word_count: confident_words.size,
          filtered_count: all_words.size - confident_words.size
        }
      end

      {
        has_text: clean_text.length >= MIN_TEXT_LENGTH,
        text: full_text,
        text_length: clean_text.length,
        words: confident_words,
        stats: stats
      }
    end

    def save_json(results, json_path)
      # words 배열은 너무 길 수 있으므로 요약 버전도 생성
      output = {
        generated_at: Time.now.iso8601,
        total_images: results.size,
        images_with_text: results.count { |r| r[:has_text] },
        images_without_text: results.count { |r| !r[:has_text] },
        sections: results.map do |r|
          {
            filename: r[:filename],
            has_text: r[:has_text],
            text_length: r[:text_length],
            text: r[:text],
            stats: r[:stats],
            words: r[:words]
          }
        end
      }

      File.write(json_path, JSON.pretty_generate(output))
    end
  end
end
