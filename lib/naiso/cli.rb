# frozen_string_literal: true

require 'optparse'

module Naiso
  # CLI 인터페이스
  class CLI
    def initialize
      @options = {
        threshold: 10.0,
        gap: 50,
        min_height: nil,
        max_height: nil,
        output: nil,
        check_text: false,
        json_output: nil,
        merge: false,
        merge_only: false
      }
    end

    def run(args = ARGV)
      parse_args(args)

      # 병합만 수행하는 경우
      if @options[:merge_only]
        ImageMerger.merge_sections(@options[:merge_only])
        return
      end

      config = SplitConfig.new(
        variance_threshold: @options[:threshold],
        min_gap_height: @options[:gap],
        min_section_height: @options[:min_height],
        max_section_height: @options[:max_height]
      )

      splitter = ImageSplitter.new(config)
      result = splitter.split(@options[:image], output_dir: @options[:output])

      # 텍스트 검출 옵션이 활성화된 경우
      if @options[:check_text] && result.output_files.any?
        detector = TextDetector.new

        # JSON 경로 결정 (지정하지 않으면 출력 디렉토리에 자동 생성)
        json_path = @options[:json_output]
        if json_path.nil? && @options[:check_text]
          output_dir = @options[:output] || File.join(File.dirname(@options[:image]), 'sections')
          base_name = File.basename(@options[:image], '.*')
          json_path = File.join(output_dir, "#{base_name}_text_analysis.json")
        end

        detector.analyze_images(result.output_files, json_path: json_path)
      end

      # 병합 옵션이 활성화된 경우
      if @options[:merge] && result.output_files.any?
        output_dir = @options[:output] || File.join(File.dirname(@options[:image]), 'sections')
        ImageMerger.merge_sections(output_dir)
      end
    end

    private

    def parse_args(args)
      parser = OptionParser.new do |opts|
        opts.banner = "사용법: naiso [옵션] <이미지>"
        opts.separator ''
        opts.separator '상품 상세 이미지를 섹션별로 분할합니다.'
        opts.separator ''
        opts.separator '옵션:'

        opts.on('-t', '--threshold FLOAT', Float, '단색 판정 임계값 (기본: 10.0)') do |v|
          @options[:threshold] = v
        end

        opts.on('-g', '--gap INT', Integer, '최소 단색 영역 높이 (기본: 50px)') do |v|
          @options[:gap] = v
        end

        opts.on('-m', '--min-height INT', Integer, '최소 섹션 높이 (기본: 이미지 너비의 2/3)') do |v|
          @options[:min_height] = v
        end

        opts.on('-M', '--max-height INT', Integer, '최대 섹션 높이 (기본: 이미지 너비의 1.5배)') do |v|
          @options[:max_height] = v
        end

        opts.on('-o', '--output DIR', '출력 디렉토리') do |v|
          @options[:output] = v
        end

        opts.on('-c', '--check-text', '분할 후 텍스트 분석 (크기 정보 포함)') do
          @options[:check_text] = true
        end

        opts.on('-j', '--json FILE', 'JSON 결과 저장 경로 (-c 옵션 필요)') do |v|
          @options[:json_output] = v
        end

        opts.on('--merge', '분할된 이미지를 다시 하나로 병합') do
          @options[:merge] = true
        end

        opts.on('--merge-only DIR', '기존 섹션 이미지들을 병합만 수행') do |v|
          @options[:merge_only] = v
        end

        opts.on('-v', '--version', '버전 표시') do
          puts "naiso #{Naiso::VERSION}"
          exit
        end

        opts.on('-h', '--help', '도움말 표시') do
          puts opts
          exit
        end

        opts.separator ''
        opts.separator '예시:'
        opts.separator '  naiso detail.jpg'
        opts.separator '  naiso detail.jpg -t 5 -g 100 -m 400'
        opts.separator '  naiso detail.jpg -M 1200'
        opts.separator '  naiso detail.jpg -c  # 텍스트 분석 포함'
        opts.separator '  naiso detail.jpg -c -j result.json  # JSON 저장'
        opts.separator '  naiso detail.jpg --merge  # 분할 후 병합'
        opts.separator '  naiso --merge-only sections/  # 기존 섹션 병합'
      end

      parser.parse!(args)

      @options[:image] = args[0] || 'detail.jpg'
    end
  end
end
