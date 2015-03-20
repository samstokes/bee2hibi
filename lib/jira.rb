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

      parse_issue(response)
    end

    private
    def checking_success
      yield.tap do |response|
        raise Error, parse_error(response), caller.drop(2) unless response.success?
      end
    end

    def parse_error(response)
      JSON.parse(response.body).fetch('errorMessages').join(', ')
    rescue
      "unexpected response format: #{response.body}"
    end

    def parse_issue(response)
      properties = JSON.parse(response.body)
      fields = properties.fetch('fields')

      Issue.new(
        properties.fetch('key'),
        fields.fetch('summary')
      )
    end
  end
end
