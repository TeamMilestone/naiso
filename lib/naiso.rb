# frozen_string_literal: true

require_relative 'naiso/version'
require_relative 'naiso/split_config'
require_relative 'naiso/split_result'
require_relative 'naiso/row_analyzer'
require_relative 'naiso/split_point_detector'
require_relative 'naiso/image_splitter'
require_relative 'naiso/image_merger'
require_relative 'naiso/text_detector'
require_relative 'naiso/cli'

module Naiso
  class Error < StandardError; end
end
