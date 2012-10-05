begin
  require 'delayed/jruby_worker'
  worker = Delayed::JRubyWorker.new(:quiet => true)
  worker.start
rescue => e
  if defined?(Rails.logger)
    Rails.logger.fatal(e)
  else
    STDERR.puts "Error starting JRubyWorker: #{e.message}"
    STDERR.puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
  end
  raise e
end