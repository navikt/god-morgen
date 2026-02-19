# frozen_string_literal: true

require_relative '../config/valkey'

class ValkeyClient
  def initialize
    @valkey = ValkeyConfig.client
  end

  def save_schedule(user_id, schedule)
    @valkey.set(user_id, schedule.to_json)
  end

  def get_schedule(user_id)
    data = @valkey.get(user_id)
    data ? JSON.parse(data) : nil
  end

  def all_user_ids
    @valkey.keys('*')
  end
end
