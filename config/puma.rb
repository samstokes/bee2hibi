workers Integer(ENV['WEB_CONCURRENCY'] || 2)

preload_app!

port ENV['PORT'] || 9292
environment ENV['RACK_ENV'] || 'development'
