# Naiso

상품 상세 이미지 섹션 분할 도구

긴 세로형 상품 상세 이미지를 섹션별로 자동 분할하고, 텍스트 유무를 분석하는 Ruby gem입니다.

## 설치

### 시스템 요구사항

```bash
# macOS
brew install vips
brew install tesseract tesseract-lang

# Ubuntu/Debian
sudo apt-get install libvips-dev tesseract-ocr tesseract-ocr-kor
```

### Gem 설치

```bash
gem install naiso
```

또는 Gemfile에 추가:

```ruby
gem 'naiso'
```

### 버전 정보
- Ruby 2.7+
- libvips 8.10+
- Tesseract 4.x / 5.x

## 기능

### 1. 이미지 분할

긴 상세 이미지를 다음 기준으로 자동 분할합니다:

| 감지 유형 | 설명 |
|----------|------|
| 단색 영역 | 연속된 solid color 배경 (variance < threshold) |
| 구분선 | 가로 방향 구분선 (위아래 여백이 단색) |
| 배경색 전환 | 흰색→회색 등 배경색이 바뀌는 지점 |
| 복잡도 기반 | 최대 높이 초과 시 엣지 밀도가 낮은 지점 |

### 2. 텍스트 분석 (OCR)

분할된 섹션에서 텍스트 유무와 크기 정보를 분석합니다.

**분석 정보:**
- 텍스트 유무 (has_text)
- 글자 수 (text_length)
- 단어별 위치/크기 (x, y, width, height)
- 통계 (min/max/avg 높이, 단어 수)

### 3. 이미지 병합

분할된 섹션들을 다시 하나로 합칩니다.

## CLI 사용법

```bash
# 기본 분할
naiso detail.jpg

# 옵션 지정
naiso detail.jpg -t 5 -g 100 -m 400

# 텍스트 분석 포함
naiso detail.jpg -c

# JSON 결과 저장
naiso detail.jpg -c -j result.json

# 분할 후 병합
naiso detail.jpg --merge

# 기존 섹션만 병합
naiso --merge-only sections/
```

### CLI 옵션

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| `-t, --threshold FLOAT` | 단색 판정 임계값 | 10.0 |
| `-g, --gap INT` | 최소 단색 영역 높이 | 50px |
| `-m, --min-height INT` | 최소 섹션 높이 | 너비 × 2/3 |
| `-M, --max-height INT` | 최대 섹션 높이 | 너비 × 1.5 |
| `-o, --output DIR` | 출력 디렉토리 | sections/ |
| `-c, --check-text` | 텍스트 분석 수행 | - |
| `-j, --json FILE` | JSON 결과 저장 경로 | 자동 생성 |
| `--merge` | 분할 후 병합 | - |
| `--merge-only DIR` | 섹션 병합만 수행 | - |
| `-v, --version` | 버전 표시 | - |
| `-h, --help` | 도움말 표시 | - |

## Ruby API

```ruby
require 'naiso'

# 이미지 분할
config = Naiso::SplitConfig.new(
  variance_threshold: 5.0,
  min_gap_height: 100,
  min_section_height: 400
)
splitter = Naiso::ImageSplitter.new(config)
result = splitter.split('detail.jpg')

puts result.output_files      # 생성된 파일 목록
puts result.split_points      # 분할 위치
puts result.uniform_regions   # 감지된 단색 영역

# 텍스트 분석
detector = Naiso::TextDetector.new
analysis = detector.detect_with_size('section_01.jpg')

puts analysis[:has_text]      # true/false
puts analysis[:text]          # 검출된 텍스트
puts analysis[:stats]         # 통계 정보

# 여러 이미지 분석
detector.analyze_images(result.output_files, json_path: 'result.json')

# 이미지 병합
Naiso::ImageMerger.merge_sections('sections/')

# 개별 이미지 병합
Naiso::ImageMerger.merge(['img1.jpg', 'img2.jpg'], 'output.jpg')
```

## 출력 파일

```
sections/
├── detail_section_01.jpg
├── detail_section_02.jpg
├── ...
├── detail_text_analysis.json  # -c 옵션 시
└── detail_merged.jpg          # --merge 옵션 시
```

## JSON 출력 형식

```json
{
  "generated_at": "2025-12-10T18:00:00+09:00",
  "total_images": 11,
  "images_with_text": 10,
  "images_without_text": 1,
  "sections": [
    {
      "filename": "detail_section_01.jpg",
      "has_text": true,
      "text_length": 22,
      "text": "검출된 텍스트...",
      "stats": {
        "min_height": 15,
        "max_height": 48,
        "avg_height": 30.6,
        "word_count": 18,
        "filtered_count": 5
      },
      "words": [
        {
          "text": "단어",
          "x": 100,
          "y": 50,
          "width": 40,
          "height": 30,
          "conf": 92.5
        }
      ]
    }
  ]
}
```

## 의존성

- [ruby-vips](https://github.com/libvips/ruby-vips) - 이미지 처리
- [numo-narray](https://github.com/ruby-numo/numo-narray) - 수치 배열 연산
- [rtesseract](https://github.com/dannnylo/rtesseract) - OCR (Tesseract 래퍼)

## 라이선스

MIT License
