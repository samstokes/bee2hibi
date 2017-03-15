require 'json'
require 'raven'
require 'sinatra/base'

require 'hibi'
require 'password_param_auth'


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
    task_id = "#{slug}_#{datestamp now}"

    logger.info "Got reminder for task #{task_id}"

    goal_title = goal.fetch('title')
    pledge = goal.fetch('pledge')
    time_left_seconds = goal.fetch('losedate') - now.to_i
    time_left_hours = time_left_seconds / 3600

    if time_left_seconds > THRESHOLD
      logger.info "Ignored task #{task_id} due to #{time_left_hours} hours left"
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
