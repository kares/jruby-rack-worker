begin
  require 'resque/jruby_worker'
  queues = (ENV['QUEUES'] || ENV['QUEUE'] || '*').to_s.split(',')
  worker = Resque::JRubyWorker.new(*queues)
  
  worker.verbose = ENV['LOGGING'] || ENV['VERBOSE']
  worker.very_verbose = ENV['VVERBOSE']
  
  if ! worker.verbose && ! worker.very_verbose
    worker.logger = Rails.logger if defined?(Rails.logger)
  end
  
  worker.log "Starting worker #{worker}"
  
  ENV['INTERVAL'] ? worker.work(ENV['INTERVAL']) : worker.work
rescue Resque::NoQueueError => e
  msg = "ENV['QUEUES'] or ENV['QUEUE'] is empty, please set it, e.g. \n" + 
  "<context-param>\n" +
  "  <param-name>jruby.worker.script</param-name>\n" +
  "  <param-value>\n" +
  "    ENV['QUEUES'] = 'critical,high'\n" +
  "    load 'resque/start_worker.rb'\n" +
  "  </param-value>\n" +
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