begin
  require 'delayed/jruby_worker'
  worker = Delayed::JRubyWorker.new(:quiet => true)
  worker.start
rescue => e
  Rails.logger.fatal(e) if defined?(Rails.logger)
  STDERR.puts e.message
  raise e
end