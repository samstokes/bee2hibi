require 'raven'

require './config/env'
require './lib/hibi'

namespace :reminders do
  desc 'Remove any old reminder tasks'
  task :gc do
    begin
      hibi = Hibi::Client.new(HIBI_OPTS)

      tasks = hibi.my_ext_tasks(SOURCE_BEEMINDER)

      # /ext_tasks doesn't include task status, so can't filter that way.
      # Just remove any task that got down to 0h remaining - either we dealt
      # with the emergency and forgot to remove the task, or we derailed, but
      # either way the task is no longer helpful.
      old_tasks = tasks.select do |task|
        raise "Unexpected ext_status: #{task.ext_status.inspect}" unless task.ext_status =~ /^(\d+)h$/i
        hours = Integer($1)
        hours == 0
      end

      old_tasks.each {|t| p t } # TODO need to augment API to allow deletes and surface task ids first
    rescue => e
      Raven.capture_exception(e)
      raise
    end
  end
end
