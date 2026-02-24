# frozen_string_literal: true

require 'json'
require 'time'

class JsonLogger
  def info(message, **fields)
    log(level: 'info', message: message, **fields)
  end

  def error(message, **fields)
    log(level: 'error', message: message, **fields)
  end

  private

  def log(level:, message:, **fields)
    entry = { timestamp: Time.now.utc.iso8601, level: level, message: message }.merge(fields)
    puts entry.to_json
  end
end
