# frozen_string_literal: true

bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 4567)}"
workers 2
threads 1, 5
environment ENV.fetch('RACK_ENV', 'production')
