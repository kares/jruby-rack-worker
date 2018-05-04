require 'jruby/rack/worker/env'

env = JRuby::Rack::Worker::ENV

if queues = ( env['QUEUES'] || env['QUEUE'] )
  Delayed::Worker.queues = queues.split(',')
end

Delayed::Worker.min_priority = env['MIN_PRIORITY'] if env['MIN_PRIORITY']
Delayed::Worker.max_priority = env['MAX_PRIORITY'] if env['MAX_PRIORITY']
