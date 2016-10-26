class PasswordParamAuth
  def initialize(app, password)
    raise if app.nil?
    @app = app
    @password = password
  end

  def call(env)
    req = Rack::Request.new(env)

    return unauthorized("What's the ?password") unless req.params.key?('password')

    if @password == req.params['password']
      return @app.call(env)
    end

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
