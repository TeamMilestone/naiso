# frozen_string_literal: true

require_relative 'lib/naiso/version'

Gem::Specification.new do |spec|
  spec.name          = 'naiso'
  spec.version       = Naiso::VERSION
  spec.authors       = ['Wonsup Yoon']
  spec.email         = ['wonsup@example.com']

  spec.summary       = '상품 상세 이미지 섹션 분할 도구'
  spec.description   = '긴 상세 이미지를 단색/그라데이션 배경 영역을 기준으로 자동 분할합니다.'
  spec.homepage      = 'https://github.com/TeamMilestone/naiso'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = ['naiso']
  spec.require_paths = ['lib']

  spec.add_dependency 'numo-narray', '~> 0.9'
  spec.add_dependency 'rtesseract', '~> 3.1'
  spec.add_dependency 'ruby-vips', '~> 2.1'
end
