begin
  require 'jruby/rack/worker/logger'
  require 'jruby/rack/worker/env'
  env = JRuby::Rack::Worker::ENV

  begin
    require 'delayed/threaded'
  rescue LoadError => e
    JRuby::Rack::Worker.log_error <<-load_error
JRuby-Rack-Worker's delayed_job support was externalized, to use it now you need to use : 

gem 'delayed-threaded'

and re-bundle your gem dependencies.
    load_error
    raise e
  end

  options = { :quiet => true }
  if queues = ( env['QUEUES'] || env['QUEUE'] )
    options[:queues] = queues.split(',')
  end
  options[:min_priority] = env['MIN_PRIORITY'] if env['MIN_PRIORITY']
  options[:max_priority] = env['MAX_PRIORITY'] if env['MAX_PRIORITY']
  # beyond `rake delayed:work` compatibility :
  if read_ahead = env['READ_AHEAD'] # DEFAULT_READ_AHEAD = 5
    options[:read_ahead] = read_ahead.to_i
  end
  if sleep_delay = env['SLEEP_DELAY'] # DEFAULT_SLEEP_DELAY = 5
    options[:sleep_delay] = sleep_delay.to_f
  end
  worker = Delayed::JRubyWorker.new(options)
  worker.start
rescue Exception => e
  if defined? JRuby::Rack::Worker.log_error
    JRuby::Rack::Worker.log_error(e)
  else
    msg = e.inspect.dup
    if backtrace = e.backtrace
      msg << ":\n  #{backtrace.join("\n  ")}"
    end
    STDERR.puts(msg) || true
  end || raise(e)
end