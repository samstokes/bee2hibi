if ENV['RACK_ENV'] != 'production'
  require 'dotenv'
  Dotenv.load
end

HIBI_OPTS = {
  server: ENV.fetch('HIBI_SERVER'),
  user: ENV.fetch('HIBI_USER'),
  password: ENV.fetch('HIBI_PASSWORD'),
}

BEEMINDER_USER = ENV.fetch('BEEMINDER_USER')

WEBHOOK_PASSWORD = ENV['WEBHOOK_PASSWORD']

UTC_OFFSET = ENV['UTC_OFFSET'] || Time.now.strftime('%:z')

SENTRY_DSN = ENV['SENTRY_DSN']

SOURCE_BEEMINDER = 'bee'
THRESHOLD = 24 * 60 * 60
