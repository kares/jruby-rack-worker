require 'jruby/rack/worker/logger'
require 'jruby/rack/worker/env'
env = JRuby::Rack::Worker::ENV
begin
  require 'resque/jruby_worker'
  queues = (env['QUEUES'] || env['QUEUE'] || '*').to_s.split(',')
  worker = Resque::JRubyWorker.new(*queues)
  
  if worker.respond_to?(:very_verbose) && ! defined?(Resque.logger)
    worker.verbose = env['LOGGING'] || env['VERBOSE']
    worker.very_verbose = env['VVERBOSE']
    if ! worker.verbose && ! worker.very_verbose
      worker.logger = Rails.logger if defined?(Rails.logger)
    end
  else # 2.0 [master] (no verbose=) or >= 1.23.0 (verbose= deprecated)
    if ( logging = env['LOGGING'] || env['VERBOSE'] ) && worker.logger
      if level = Logger.const_get(logging.upcase) rescue nil
        worker.logger.level = level
      end
    else
      worker.logger = Rails.logger if defined?(Rails.logger)
    end
  end
  
  worker.log "Starting worker #{worker}"
  interval = env['INTERVAL']
  interval ? worker.work(interval) : worker.work
rescue Resque::NoQueueError => e
  msg = "ENV['QUEUES'] or ENV['QUEUE'] is empty, please set it " +
  "(or remove it and worker will process all '*' queues), e.g.\n" +
  "<context-param>\n" +
  "  <param-name>QUEUES</param-name>\n" +
  "  <param-value>critical,high</param-value>\n" +
  "</context-param>\n"
  logger = JRuby::Rack::Worker.logger
  logger && logger.error(msg)
rescue => e
  JRuby::Rack::Worker.log_error(e) || raise
end