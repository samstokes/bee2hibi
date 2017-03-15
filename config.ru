require './config/env'

$LOAD_PATH << File.expand_path('./lib')

require './app/bee2hibi'

run Bee2Hibi
