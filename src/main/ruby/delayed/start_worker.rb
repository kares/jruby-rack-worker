begin
  require 'delayed/jruby_worker'
  worker = Delayed::JRubyWorker.new(
    :min_priority => ENV['MIN_PRIORITY'],
    :max_priority => ENV['MAX_PRIORITY'],
    :queues => (ENV['QUEUES'] || ENV['QUEUE'] || '').split(','),
    :quiet => true
  )
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