require 'rack/honeycomb'

class PasswordParamAuth
  def initialize(app, password)
    raise if app.nil?
    @app = app
    @password = password
  end

  def call(env)
    req = Rack::Request.new(env)

    unless req.params.key?('password')
      Rack::Honeycomb.add_field(env, :authenticated, false)
      return unauthorized("What's the ?password")
    end

    if @password == req.params['password']
      Rack::Honeycomb.add_field(env, :authenticated, true)
      return @app.call(env)
    end

    Rack::Honeycomb.add_field(env, :authenticated, 'bad')
    unauthorized("?password incorrect")
  end

  private
  def unauthorized(challenge)
    return [
      401,
      {'Content-Type' => 'text/plain'},
      [challenge]
    ]
  end
end
