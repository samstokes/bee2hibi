if ENV['RACK_ENV'] != 'production'
  require 'dotenv'
  Dotenv.load
end

$LOAD_PATH << File.expand_path('./lib')

require './app/bee2hibi'

run Bee2Hibi
