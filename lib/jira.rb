require 'cgi'
require 'faraday'
require 'json'
require 'ostruct'

module Jira
  class Error < RuntimeError; end

  class Issue < OpenStruct
    def initialize(url_base, *args)
      @url_base = url_base
      super(*args)
    end

    def web_url
      "#@url_base/browse/#{CGI.escape key}"
    end
  end

  class Client
    attr_reader :user

    def initialize(opts = {})
      @server = opts.fetch :server
      @user = opts.fetch :user
      password = opts.fetch :password
      @api_base = opts[:api_base] || '/rest/api/2'

      @conn = Faraday.new(@server, ssl: {verify: false})
      @conn.basic_auth(@user, password)
    end

    def issue(key)
      response = checking_success do
        @conn.get "#@api_base/issue/#{CGI.escape key}"
      end

      parse_issue_json(response.body)
    end

    def my_issues
      jql = jql_my_issues
      search(jql)
    end

    def search(jql)
      response = checking_success do
        @conn.get "#@api_base/search", jql: jql
      end
      parse_issues_json(response.body)
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
        "bad request: #{parse_errors_from_body(response).join(', ')}"
      when 401
        "unauthorized: #{parse_errors_from_body(response).join(', ')}"
      else
        "status #{response.status}"
      end
    rescue
      "unexpected response: #{response.inspect}"
    end

    def parse_errors_from_body(response)
      JSON.parse(response.body).fetch('errorMessages')
    end

    def parse_issue_json(json)
      properties = JSON.parse(json)
      parse_issue(properties)
    end

    def parse_issue(properties)
      fields = properties.fetch('fields')
      Issue.new(@server,
        key: properties.fetch('key'),
        summary: fields.fetch('summary'),
        status: parse_status(fields.fetch('status')),
        assignee: parse_user(fields.fetch('assignee')),
      )
    end

    def parse_status(properties)
      properties.fetch('name')
    end

    def parse_user(properties)
      properties.fetch('name')
    end

    def parse_issues_json(json)
      properties = JSON.parse(json)
      issues = properties.fetch('issues')
      issues.map do |issue_properties|
        parse_issue(issue_properties)
      end
    end

    def jql_my_issues
      assignee_p = 'assignee=currentUser()'
      in_progress_p = 'status NOT IN (Open, Reopened, Closed, Completed, Blocked)'
      current_sprint_p = "sprint IN openSprints() AND status IN (Open, Reopened)"
      relevant_p = "(#{current_sprint_p}) OR (#{in_progress_p})"
      orders = ['status']
      "(#{assignee_p}) AND (#{relevant_p}) ORDER BY #{orders.join(', ')}"
    end
  end
end
