begin
  require 'resque/jruby_worker'
  queues = (ENV['QUEUES'] || ENV['QUEUE'] || '*').to_s.split(',')
  worker = Resque::JRubyWorker.new(*queues)
  worker.verbose = ENV['LOGGING'] || ENV['VERBOSE']
  worker.very_verbose = ENV['VVERBOSE']
  
  worker.log "Starting worker #{worker}"
  
  if ! worker.verbose && ! worker.very_verbose
    worker.logger = Rails.logger if defined?(Rails.logger)
  end
  
  ENV['INTERVAL'] ? worker.work(ENV['INTERVAL']) : worker.work  
rescue Resque::NoQueueError => e
  msg = "ENV['QUEUES'] is empty, please set it, e.g. \n" + 
  "<context-param>\n" +
  "  <param-name>jruby.worker.script</param-name>\n" +
  "  <param-value>\n" +
  "    ENV['QUEUES'] = 'critical,high'\n" +
  "    load 'resque/start_worker.rb'\n" +
  "  </param-value>\n" +
  "</context-param>\n"
  Rails.logger.error(msg) if defined?(Rails.logger)
  STDERR.puts msg
  raise e
rescue => e
  Rails.logger.fatal(e) if defined?(Rails.logger)
  STDERR.puts e.message
  raise e
end