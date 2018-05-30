require 'json'
require 'honeycomb-beeline'
require 'raven'
require 'sinatra/base'

require 'hibi'
require 'password_param_auth'

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

Honeycomb.init service_name: 'bee2hibi'

class Bee2Hibi < Sinatra::Application
  def initialize
    @hibi = Hibi::Client.new(HIBI_OPTS)

    super
  end

  use PasswordParamAuth, WEBHOOK_PASSWORD if WEBHOOK_PASSWORD

  if SENTRY_DSN
    Raven.configure do |config|
      config.dsn = SENTRY_DSN
    end

    use Raven::Rack
  end

  post '/reminder' do
    json = JSON.parse(request.body.read)

    goal = json.fetch('goal')
    now = Time.now

    slug = goal.fetch('slug')
    add_honeycomb_field :goal_slug, slug
    task_id = "#{slug}_#{datestamp now}"
    add_honeycomb_field :task_id, task_id

    logger.info "Got reminder for task #{task_id}"

    goal_title = goal.fetch('title')
    pledge = goal.fetch('pledge')
    add_honeycomb_field :pledge, pledge
    time_left_seconds = goal.fetch('losedate') - now.to_i
    add_honeycomb_field :time_left_seconds, time_left_seconds
    time_left_hours = time_left_seconds / 3600

    if time_left_seconds > THRESHOLD
      logger.info "Ignored task #{task_id} due to #{time_left_hours} hours left"
      add_honeycomb_field :ignored, true
      status 202
      return "ignored due to #{time_left_hours} hours left"
    end

    task_title = "#{goal_title}"
    task_status = "#{time_left_hours}h, $#{pledge}"

    task = Hibi::Task.new(
      ext_id: task_id,
      title: task_title,
      schedule: 'Once',
      ext_source: SOURCE_BEEMINDER,
      ext_url: goal_url(goal),
      ext_status: task_status,
    )

    result = @hibi.create_or_update_task(task)
    logger.info "Updated task #{task_id} in Hibi"

    add_honeycomb_field :hibi_post_status, result.status
    status result.status
    result.body
  end

  private
  def goal_url(goal)
    "https://beeminder.com/#{BEEMINDER_USER}/#{goal.fetch 'slug'}"
  end

  def datestamp(time)
    time.clone.localtime(UTC_OFFSET).strftime('%Y-%m-%d')
  end
end
