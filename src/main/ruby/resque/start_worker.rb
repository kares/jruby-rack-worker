require 'jruby/rack/worker/env'
env = JRuby::Rack::Worker::ENV
begin
  require 'resque/jruby_worker'
  queues = (env['QUEUES'] || env['QUEUE'] || '*').to_s.split(',')
  worker = Resque::JRubyWorker.new(*queues)
  
  worker.verbose = env['LOGGING'] || env['VERBOSE']
  worker.very_verbose = env['VVERBOSE']
  
  if ! worker.verbose && ! worker.very_verbose
    worker.logger = Rails.logger if defined?(Rails.logger)
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
  Rails.logger.error(msg) if defined?(Rails.logger)
  STDERR.puts msg
rescue => e
  if defined?(Rails.logger)
    Rails.logger.fatal(e)
  else
    STDERR.puts "Error starting JRubyWorker: #{e.message}"
    STDERR.puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
  end
  raise e
end