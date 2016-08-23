begin
  require 'jruby/rack/worker/logger'
  require 'jruby/rack/worker/env'
  env = JRuby::Rack::Worker::ENV

  require 'resque/jruby_worker'

  queues = (env['QUEUES'] || env['QUEUE'] || '*').to_s.split(',')
  verbose = env['LOGGING'] || env['VERBOSE']
  very_verbose = env['VVERBOSE']

  if defined? Resque::Options # Resque::VERSION >= 2.0.0
    queues << ( options = {
        :daemon => false,
        :fork_per_job => false,
        :run_at_exit_hooks => true
    } )
    timeout = env['TIMEOUT'] || env['timeout']
    options[:timeout] = Float(timeout) if timeout
    interval = env['INTERVAL'] || env['interval']
    options[:interval] = Float(interval) if interval
    interval = nil # work() does not accept argument
  else
    interval = env['INTERVAL']
  end

  worker = Resque::JRubyWorker.new(*queues)

  if worker.respond_to?(:very_verbose) && ! defined?(Resque.logger)
    worker.verbose = verbose
    worker.very_verbose = very_verbose
    if ! worker.verbose && ! worker.very_verbose
      worker.logger = Rails.logger if defined?(Rails.logger)
    end
  else # 2.0 [master] (no verbose=) or >= 1.23.0 (verbose= deprecated)
    if verbose && worker.logger
      level = Integer(verbose) rescue verbose
      unless level.is_a?(Numeric)
        level = level.to_s.strip.upcase
        unless ( Logger::Severity.const_defined?(level) rescue nil )
          level = 'INFO'
        end
        level = Logger.const_get(level)
      end
      worker.logger.level = level if level
    elsif very_verbose && worker.logger
      worker.logger.level = Logger::DEBUG
    else
      worker.logger = Rails.logger if defined?(Rails.logger)
    end
  end

  worker.log "Starting worker #{worker}"

  interval ? worker.work(interval) : worker.work

rescue Resque::NoQueueError => e
  msg = "ENV['QUEUES'] or ENV['QUEUE'] is empty, please set it " +
  "(or remove it and worker will process all '*' queues), e.g.\n" +
  "<context-param>\n" +
  "  <param-name>QUEUES</param-name>\n" +
  "  <param-value>critical,high</param-value>\n" +
  "</context-param>\n"
  logger = JRuby::Rack::Worker.logger
  logger && logger.error(msg)
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