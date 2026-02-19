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
      text: 'Set Status Schedule'
    },
    submit: {
      type: 'plain_text',
      text: 'Submit'
    },
    close: {
      type: 'plain_text',
      text: 'Cancel'
    },
    blocks: [
      *day_blocks('monday', 'Monday'),
      *day_blocks('tuesday', 'Tuesday'),
      *day_blocks('wednesday', 'Wednesday'),
      *day_blocks('thursday', 'Thursday'),
      *day_blocks('friday', 'Friday')
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
        text: 'Status description'
      },
      element: {
        type: 'plain_text_input',
        action_id: "#{day}_text_input",
        placeholder: {
          type: 'plain_text',
          text: 'e.g. Working from home'
        }
      }
    },
    {
      type: 'input',
      block_id: "#{day}_emoji",
      label: {
        type: 'plain_text',
        text: 'Status emoji'
      },
      element: {
        type: 'plain_text_input',
        action_id: "#{day}_emoji_input",
        placeholder: {
          type: 'plain_text',
          text: 'e.g. :small_house_hidden_dino:'
        }
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
      'emoji' => values["#{day}_emoji"]["#{day}_emoji_input"]['value']
    }
  end

  valkey.save_schedule(user_id, schedule)

  content_type :json
  { response_action: 'clear' }.to_json
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
