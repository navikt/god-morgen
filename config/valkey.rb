# frozen_string_literal: true

require 'redis'

module ValkeyConfig
  def self.client
    instance = 'GOD-MORGEN'

    @client ||= Redis.new(
      host: ENV["VALKEY_HOST_#{instance}"] || ENV['VALKEY_HOST'] || 'localhost',
      port: (ENV["VALKEY_PORT_#{instance}"] || ENV['VALKEY_PORT'] || 6379).to_i,
      username: ENV["VALKEY_USERNAME_#{instance}"] || ENV.fetch('VALKEY_USERNAME', nil),
      password: ENV["VALKEY_PASSWORD_#{instance}"] || ENV.fetch('VALKEY_PASSWORD', nil),
      ssl: ENV.key?("VALKEY_HOST_#{instance}")
    )
  end
end
