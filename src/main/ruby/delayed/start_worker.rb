require 'jruby/rack/worker/env'
env = JRuby::Rack::Worker::ENV
begin
  require 'delayed/jruby_worker'
  options = { :quiet => true }
  options[:queues] = (env['QUEUES'] || env['QUEUE'] || '').split(',')
  options[:min_priority] = env['MIN_PRIORITY']
  options[:max_priority] = env['MAX_PRIORITY']
  # beyond `rake delayed:work` compatibility :
  if read_ahead = env['READ_AHEAD'] # DEFAULT_READ_AHEAD = 5
    options[:read_ahead] = read_ahead.to_i
  end
  if sleep_delay = env['SLEEP_DELAY'] # DEFAULT_SLEEP_DELAY = 5
    options[:sleep_delay] = sleep_delay.to_f
  end
  worker = Delayed::JRubyWorker.new(options)
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