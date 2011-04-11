begin
  require 'navvy/jruby_worker'
  Navvy::JRubyWorker.start
rescue => e
  Rails.logger.fatal(e) if defined?(Rails.logger)
  STDERR.puts e.message
  raise e
end