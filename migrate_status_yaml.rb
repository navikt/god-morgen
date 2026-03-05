#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require_relative 'lib/valkey_client'
require_relative 'lib/slack_client'

def migrate(valkey, slack)
  config_file = 'status.yaml'

  unless File.exist?(config_file)
    puts "Config file '#{config_file}' not found"
    exit 1
  end

  data = YAML.load_file(config_file)

  migrated = 0
  skipped = 0

  data.each do |user_id, schedule|
    next unless user_id && schedule

    existing = valkey.get_schedule(user_id)
    if existing
      puts "Skipping #{user_id}: already has schedule"
      skipped += 1
      next
    end

    valkey.save_schedule(user_id, schedule)
    migrated += 1
    puts "Migrated #{user_id}"
    notify(slack, user_id)
  end

  puts "Done. Migrated: #{migrated}, Skipped: #{skipped}"
end

def notify(slack, user_id)
  dm_result = slack.send_dm(user_id, 'Du er nå migrert til den nye God morgen-løsningen. ' \
                                     'Du vil fortsette å motta daglige statuser, bare med en ' \
                                     'liten melding hver dag om at status er satt..')
  if dm_result && dm_result['ok']
    puts "DM sendt til #{user_id}"
  else
    puts "Feil ved sending av DM til #{user_id}: #{dm_result && dm_result['error']}"
  end
rescue StandardError => e
  puts "Unntak ved sending av DM til #{user_id}: #{e.message}"
end
