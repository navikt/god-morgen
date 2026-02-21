#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra'
require 'json'
require 'net/http'
require 'date'
require_relative 'lib/valkey_client'
require_relative 'lib/slack_client'

valkey = ValkeyClient.new
slack = SlackClient.new(ENV.fetch('SLACK_BOT_TOKEN', nil))

set :port, 4567

post '/slack/interactions' do
  payload = JSON.parse(params['payload'])

  case payload['type']
  when 'view_submission'
    handle_form_submission(payload)
  end
end

post '/slack/commands' do
  trigger_id = params['trigger_id']

  open_modal(trigger_id)

  status 200
  body ''
end

def open_modal(trigger_id)
  uri = URI('https://slack.com/api/views.open')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Post.new(uri)
  request['Authorization'] = "Bearer #{ENV.fetch('SLACK_BOT_TOKEN', nil)}"
  request['Content-Type'] = 'application/json'

  request.body = {
    trigger_id: trigger_id,
    view: modal_view
  }.to_json

  response = http.request(request)
  result = JSON.parse(response.body)

  return if result['ok']

  puts "Error opening modal: #{result['error']}"
end

def modal_view
  {
    type: 'modal',
    callback_id: 'schedule_modal',
    title: {
      type: 'plain_text',
      text: 'Ukentlig status'
    },
    submit: {
      type: 'plain_text',
      text: 'Lagre'
    },
    close: {
      type: 'plain_text',
      text: 'Avbryt'
    },
    blocks: [
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: 'Sett opp din ukentlige statusplan. For hver dag, skriv en statusbeskrivelse og velg en emoji  ' \
                'ved hjelp av emoji-velgeren 🎉'
        }
      },
      { type: 'divider' },
      *day_blocks('monday', 'Mandag'),
      *day_blocks('tuesday', 'Tirsdag'),
      *day_blocks('wednesday', 'Onsdag'),
      *day_blocks('thursday', 'Torsdag'),
      *day_blocks('friday', 'Fredag')
    ]
  }
end

def day_blocks(day, label)
  [
    {
      type: 'header',
      text: {
        type: 'plain_text',
        text: label
      }
    },
    {
      type: 'input',
      block_id: "#{day}_text",
      label: {
        type: 'plain_text',
        text: 'Statusbeskrivelse'
      },
      element: {
        type: 'plain_text_input',
        action_id: "#{day}_text_input",
        placeholder: {
          type: 'plain_text',
          text: 'f.eks. Hjemmekontor'
        }
      }
    },
    {
      type: 'input',
      block_id: "#{day}_emoji",
      label: {
        type: 'plain_text',
        text: 'Statusemoji'
      },
      element: {
        type: 'rich_text_input',
        action_id: "#{day}_emoji_input"
      }
    }
  ]
end

def handle_form_submission(payload)
  user_id = payload['user']['id']
  values = payload['view']['state']['values']

  schedule = %w[monday tuesday wednesday thursday friday].each_with_object({}) do |day, hash|
    hash[day] = {
      'text' => values["#{day}_text"]["#{day}_text_input"]['value'],
      'emoji' => extract_emoji(values["#{day}_emoji"]["#{day}_emoji_input"])
    }
  end

  valkey.save_schedule(user_id, schedule)

  content_type :json
  { response_action: 'clear' }.to_json
end

# Extract the first emoji from a rich_text_input value.
# Payload structure: { "type" => "rich_text", "elements" => [
#   { "type" => "rich_text_section", "elements" => [
#     { "type" => "emoji", "name" => "house" }
#   ]}
# ]}
def extract_emoji(rich_text)
  return nil unless rich_text

  elements = rich_text.dig('rich_text_value', 'elements') || []
  elements.each do |section|
    next unless section['elements']

    section['elements'].each do |el|
      return ":#{el['name']}:" if el['type'] == 'emoji'
    end
  end

  nil
end

post '/api/apply-statuses' do
  content_type :json

  today = Date.today.strftime('%A').downcase
  user_ids = valkey.all_user_ids
  results = []

  user_ids.each do |user_id|
    schedule = valkey.get_schedule(user_id)
    next unless schedule

    status_config = schedule[today]
    next unless status_config

    result = slack.set_status(user_id, status_config['text'], status_config['emoji'])

    if result['ok']
      slack.send_dm(user_id, "God morgen! Status satt til #{status_config['emoji']} #{status_config['text']}")
      results << { user_id: user_id, status: 'ok' }
    else
      results << { user_id: user_id, status: 'error', error: result['error'] }
    end
  end

  { applied: results.size, results: results }.to_json
end
