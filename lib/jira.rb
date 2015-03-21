require 'cgi'
require 'faraday'
require 'json'

module Jira
  class Error < RuntimeError; end

  class Issue < Struct.new(:key, :summary)
  end

  class Client
    def initialize(opts = {})
      server = opts.fetch :server
      user = opts.fetch :user
      password = opts.fetch :password

      @conn = Faraday.new(server, ssl: {verify: false})
      @conn.basic_auth(user, password)
    end

    def issue(key)
      response = checking_success do
        @conn.get "/rest/api/2/issue/#{CGI.escape key}"
      end

      parse_issue_json(response.body)
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
      Issue.new(
        properties.fetch('key'),
        fields.fetch('summary')
      )
    end
  end
end
