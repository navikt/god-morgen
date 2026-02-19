#!/usr/bin/env ruby
# frozen_string_literal: true

require 'date'
require_relative 'lib/slack_client'
require_relative 'lib/valkey_client'

token = ENV.fetch('SLACK_TOKEN', nil)

unless token
  puts 'Error: SLACK_TOKEN environment variable not set'
  exit 1
end

slack = SlackClient.new(token)
valkey = ValkeyClient.new
today = Date.today.strftime('%A').downcase

user_ids = valkey.all_user_ids

user_ids.each do |user_id|
  schedule = valkey.get_schedule(user_id)
  next unless schedule

  status_config = schedule[today]
  next unless status_config

  result = slack.set_status(user_id, status_config['text'], status_config['emoji'])

  if result['ok']
    puts "#{user_id}: Status set to '#{status_config['text']}' #{status_config['emoji']}"
  else
    puts "#{user_id}: Error - #{result['error']}"
  end
end
