require 'cgi'
require 'faraday'
require 'json'
require 'ostruct'

module Hibi
  class Error < RuntimeError; end

  class Task < OpenStruct
    def ext_inactive?
      %w(Closed Completed).member?(ext_status)
    end

    def ext_active?
      !ext_inactive?
    end

    def status_assignee
      [ext_status, ext_assignee].compact.join(', ')
    end

    def to_json
      JSON.generate(
        title: title,
        schedule: schedule,
        extTask: {
          extId: ext_id,
          extSource: ext_source,
          extUrl: ext_url,
          extStatus: status_assignee,
        }
      )
    end
  end

  class Client
    API_BASE = '/api'

    def initialize(opts = {})
      server = opts.fetch :server
      user = opts.fetch :user
      password = opts.fetch :password

      @conn = Faraday.new(server, ssl: {verify: false})
      @conn.basic_auth(user, password)
    end

    def my_ext_tasks(ext_source)
      response = checking_success do
        @conn.get("#{API_BASE}/ext_tasks/#{CGI.escape ext_source}")
      end

      parse_tasks_json(response.body)
    end

    def create_or_update_task(task)
      checking_success do
        @conn.post("#{API_BASE}/tasks", task.to_json)
      end
    end

    private
    def checking_success
      yield.tap do |response|
        raise Error, parse_error(response), caller.drop(2) unless response.success?
      end
    end

    def parse_error(response)
      case response.status
      when 400
        "bad request: #{response.body}"
      when 401
        "unauthorized: #{response.body}"
      else
        "status #{response.status}"
      end
    rescue
      "unexpected response: #{response.inspect}"
    end

    def parse_task(properties)
      ext_status, ext_assignee = parse_status_assignee(properties.fetch('ext_status'))
      Task.new(
        ext_id: properties.fetch('ext_id'),
        ext_status: ext_status,
        ext_assignee: ext_assignee,
      )
    end

    def parse_tasks_json(json)
      tasks = JSON.parse(json)
      tasks.map do |task_properties|
        parse_task(task_properties)
      end
    end

    def parse_status_assignee(ext_status)
      ext_status.split(/\s*,\s*/)
    end
  end
end
