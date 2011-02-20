begin
  require 'delayed/jruby_worker'
  Delayed::JRubyWorker.new(:quiet => true).start
rescue => e
  Rails.logger.fatal(e) if defined?(Rails.logger)
  STDERR.puts e.message
  raise e
end