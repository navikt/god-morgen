# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

class SlackClient
  def initialize(token)
    @token = token
  end

  def set_status(user_id, text, emoji)
    uri = URI('https://slack.com/api/users.profile.set')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@token}"
    request['Content-Type'] = 'application/json'

    profile = {
      status_text: text,
      status_emoji: emoji
    }

    request.body = { profile: profile, user: user_id }.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end

  def send_dm(user_id, text)
    uri = URI('https://slack.com/api/chat.postMessage')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@token}"
    request['Content-Type'] = 'application/json'

    request.body = {
      channel: user_id,
      text: text,
      metadata: {
        event_type: 'status_set',
        event_payload: {}
      }
    }.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end
end
