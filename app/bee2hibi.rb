require 'json'
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

SOURCE_BEEMINDER = 'bee'
THRESHOLD = 24 * 60 * 60

class Bee2Hibi < Sinatra::Application
  def initialize
    @hibi = Hibi::Client.new(HIBI_OPTS)

    super
  end

  use PasswordParamAuth, WEBHOOK_PASSWORD if WEBHOOK_PASSWORD

  post '/reminder' do
    json = JSON.parse(request.body.read)

    goal = json.fetch('goal')
    now = Time.now

    slug = goal.fetch('slug')
    task_id = "#{slug}_#{now.strftime '%Y-%m-%d'}"

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
end
