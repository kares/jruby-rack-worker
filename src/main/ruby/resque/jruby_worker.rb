require 'resque' unless defined?(Resque::Worker)
require 'logger'

module Resque
  # Thread-safe worker usable with JRuby, adapts most of the methods designed
  # to be used in a process per worker env to behave safely in concurrent env.
  class JRubyWorker < Worker

    begin
      require 'jruby'
      require 'java'
      JRUBY = true
    rescue LoadError
      warn "loading #{self.name} on non-jruby"
      JRUBY = false
    end

    if RESQUE_2x = Resque.const_defined?(:WorkerRegistry)

      def initialize(*args)
        options = args.last.is_a?(Hash) ? args.pop : {}
        super(args, options) # (queues = [], options = {})
      end

      def work(&block)
        startup
        work_loop(&block)
        worker_registry.unregister
      rescue Exception => exception
        worker_registry.unregister(exception)
      end

      def fork_for_child(job, &block)
        perform(job, &block) # instead of @child.fork_and_perform(job, &block)
      end

    else # 1.2x.y

      def initialize(*queues)
        super
        @cant_fork = true
      end

      # reserve accepts an interval argument (on master)
      RESERVE_ACCEPTS_INTERVAL = instance_method(:reserve).arity != 0 # :nodoc

      # @see Resque::Worker#work
      def work(interval = 5.0, &block)
        interval = Float(interval)
        procline "Starting" # do not change $0
        startup

        loop do
          break if shutdown?

          if paused?
            procline "Paused"
            pause while paused? # keep sleeping while paused
          end

          if (job = (RESERVE_ACCEPTS_INTERVAL ? reserve(interval) : reserve))
            log "got: #{job.inspect}"

            job.worker = self
            run_hook :before_fork, job
            working_on job

            procline "Processing #{job.queue} since #{Time.now.to_i}"

            perform(job, &block)

            done_working
          else
            break if interval.zero?
            if RESERVE_ACCEPTS_INTERVAL
              log! "Timed out after #{interval} seconds"
              procline paused? ? "Paused" : "Waiting for #{queue_names}"
            else
              log! "Sleeping for #{interval} seconds"
              procline paused? ? "Paused" : "Waiting for #{queue_names}"
              sleep interval
            end
          end
        end

        unregister_worker
      rescue Exception => exception
        unregister_worker(exception)
      end

      # No forking with JRuby !
      # @see Resque::Worker#fork
      def fork # :nodoc
        @cant_fork = true
        nil # important due #work
      end

    end

    # @see Resque::Worker#enable_gc_optimizations
    def enable_gc_optimizations # :nodoc
      nil # we're definitely not REE
    end

    # @see Resque::Worker#startup
    def startup
      _term_child = @term_child
      begin
        @term_child = true # avoid the heroku warning with 1.23.0
        super
      ensure
        @term_child = _term_child
      end
      update_native_thread_name
    end

    PAUSE_SLEEP = 0.1

    # @see Resque::Worker#pause
    def pause
      sleep(PAUSE_SLEEP) # trap('CONT') makes no sense here
    end

    # @see Resque::Worker#pause_processing
    def pause_processing
      log "pausing job processing"
      @paused = true
    end

    # Registers the various signal handlers a worker responds to.
    # @see Resque::Worker#register_signal_handlers
    def register_signal_handlers
      at_exit { shutdown }
      log! "registered at_exit shutdown hook (instead of signal handlers)"
    end

    # @see Resque::Worker#unregister_signal_handlers
    def unregister_signal_handlers
      # NOTE: makes no sense since we're not child forking :
      log! "unregister_signal_handlers does nothing"
      nil
    end

    # Called from #shutdown!
    # @see Resque::Worker#kill_child
    def kill_child
      log! "kill_child has no effect with #{self.class.name}"
      nil
    end

    # Called from #shutdown!
    # @see Resque::Worker#new_kill_child
    def new_kill_child
      log! "new_kill_child has no effect with #{self.class.name}"
      nil
    end

    # @see Resque::Worker#inspect
    def inspect
      "#<JRubyWorker #{to_s}>"
    end

    # @see Resque::Worker#to_s
    def to_s
      @to_s ||= "#{hostname}:#{pid}[#{thread_id}]:#{queue_names}".freeze
    end
    alias_method :id, :to_s

    if RESQUE_2x
      def queue_names; @worker_queues.to_s; end
    else
      def queue_names; @queues.join(','); end
    end
    private :queue_names

    # @see Resque::Worker#hostname
    def hostname
      JRUBY ? java.net.InetAddress.getLocalHost.getHostName : super
    end

    # @see #worker_thread_ids
    def thread_id
      JRUBY ? java.lang.Thread.currentThread.getName : nil
    end

    # similar to the original pruning but accounts for thread-based workers
    # @see Resque::Worker#prune_dead_workers
    def prune_dead_workers
      all_workers = self.class.all
      return if all_workers.empty?
      known_workers = JRUBY ? worker_thread_ids : []
      pids = nil, hostname = self.hostname
      all_workers.each do |worker|
        host, pid, thread, queues = self.class.split_id(worker.id)
        next if host != hostname
        next if known_workers.include?(thread) && pid == self.pid.to_s
        # NOTE: allow flexibility of running workers :
        # 1. worker might run in another JVM instance
        # 2. worker might run as a process (with MRI)
        next if (pids ||= system_pids).include?(pid)
        log! "Pruning dead worker: #{worker}"
        if worker.respond_to?(:unregister_worker)
          worker.unregister_worker
        else # Resque 2.x
          Registry.for(worker).unregister
        end
      end
    end

    def self.all; WorkerRegistry.all; end if RESQUE_2x

    WORKER_THREAD_ID = 'worker'.freeze

    # returns worker thread names that supposely belong to the current application
    def worker_thread_ids
      thread_group = java.lang.Thread.currentThread.getThreadGroup
      threads = java.lang.reflect.Array.newInstance(
        java.lang.Thread.java_class, thread_group.activeCount)
      thread_group.enumerate(threads)
      # NOTE: we shall check the name from $servlet_context.getServletContextName
      # but that's an implementation detail of the factory currently that threads
      # are named including their context name. thread grouping should be fine !
      threads.map do |thread| # a convention is to name threads as "worker" :
        thread && thread.getName.index(WORKER_THREAD_ID) ? thread.getName : nil
      end.compact
    end

    # Similar to Resque::Worker#worker_pids but without the worker.pid files.
    # Since this is only used to #prune_dead_workers it's fine to return PIDs
    # that have nothing to do with resque, it's only important that those PIDs
    # contain processed that are currently live on the system and perform work.
    #
    # Thus the naive implementation to return all PIDs running within the OS
    # (under current user) is acceptable.
    def system_pids
      pids = `ps -e -o pid`.split("\n")
      pids.delete_at(0) # PID (header)
      pids.each(&:'strip!')
    end
    require 'rbconfig'
    if RbConfig::CONFIG['host_os'] =~ /mswin|mingw/i
      require 'csv'
      def system_pids
        pids_csv = `tasklist.exe /FO CSV /NH` # /FI "PID gt 1000"
        # sample output :
        # "System Idle Process","0","Console","0","16 kB"
        # "System","4","Console","0","228 kB"
        # "smss.exe","1056","Console","0","416 kB"
        # "csrss.exe","1188","Console","0","5,276 kB"
        # "winlogon.exe","1212","Console","0","4,708 kB"
        pids = CSV.parse(pids_csv).map! { |record| record[1] }
        pids.delete_at(0) # no CSV header thus first row nil
        pids
      end
    end

    if RESQUE_2x

      # Resque::JRubyWorker::Registry < Resque::WorkerRegistry
      class Registry < WorkerRegistry

        def self.for(worker)
          worker.is_a?(JRubyWorker) ? new(worker) : WorkerRegistry.new(worker)
        end

        def register
          outcome = super
          if @worker.is_a?(JRubyWorker)
            @worker.send(:system_register_worker) if JRUBY
          else
            warn "unregister called with non-jruby worker: #{@worker}"
          end
          outcome
        end

        def unregister(exception = nil)
          outcome = super
          if @worker.is_a?(JRubyWorker)
            @worker.send(:system_unregister_worker) if JRUBY
          else
            warn "unregister called with non-jruby worker: #{@worker}"
          end
          outcome
        end

      end

      def worker_registry
        @worker_registry ||= Registry.new(self)
      end

    else

      # @see Resque::Worker#register_worker
      def register_worker
        outcome = super
        system_register_worker if JRUBY
        outcome
      end

      if instance_method(:unregister_worker).arity != 0

        # @see Resque::Worker#unregister_worker
        def unregister_worker(exception = nil)
          system_unregister_worker if JRUBY
          super(exception)
        end

      else

        # @see Resque::Worker#unregister_worker
        def unregister_worker(exception = nil)
          system_unregister_worker if JRUBY
          super(); raise exception
        end

      end

    end

    # @see Resque::Worker#procline
    def procline(string = nil)
      if string.nil?
        @procline ||= nil # act as a reader if no string given
      else # avoid setting $0
        log! @procline = "resque-#{Resque::Version}: #{string}"
      end
    end

    if ( instance_method(:log) rescue nil ) && ! defined? Resque.logger

      # Log a message to STDOUT if we are verbose or very_verbose.
      # @see Resque::Worker#log
      def log(message)
        if very_verbose
          time = Time.now.strftime('%H:%M:%S %Y-%m-%d')
          name = java.lang.Thread.currentThread.getName
          logger.debug "** [#{time}] #{name}: #{message}"
        elsif verbose
          logger.info "*** #{message}"
        end
      end

      def verbose=(value)
        if value && ! very_verbose
          logger.level = Logger::INFO
        elsif ! value
          logger.level = Logger::WARN
        end
        @verbose = value
      end

      def very_verbose=(value)
        if value
          logger.level = Logger::DEBUG
        elsif ! value && verbose
          logger.level = Logger::INFO
        else
          logger.level = Logger::WARN
        end
        @very_verbose = value
      end

    else # #verbose, #very_verbose, #log, #log! removed on 2.0 [master]

      def log(message); logger.info(message); end
      def log!(message); logger.debug(message); end

    end

    def logger
      @logger ||= begin
        # [master] `Resque.logger = Logger.new(STDOUT)`
        logger = Resque.logger if defined? Resque.logger
        unless logger
          logger = Logger.new(STDOUT)
          if respond_to?(:very_verbose)
            logger.level = Logger::WARN
            logger.level = Logger::INFO if verbose
            logger.level = Logger::DEBUG if very_verbose
          else
            logger.level = Logger::INFO
          end
        end
        logger
      end
    end

    # We route log output through a logger
    # (instead of printing directly to stdout).
    def logger=(logger)
      @logger = logger
    end

    private

    # so that we can later identify a "live" worker thread
    def update_native_thread_name
      thread = JRuby.reference(Thread.current)
      set_thread_name = Proc.new do |prefix, suffix|
        self.class.with_global_lock do
          count = self.class.system_registered_workers.size
          thread.native_thread.name = "#{prefix}##{count}#{suffix}"
        end
      end
      if ! name = thread.native_thread.name
        # "#{THREAD_ID}##{count}" :
        set_thread_name.call(WORKER_THREAD_ID, nil)
      elsif ! name.index(WORKER_THREAD_ID)
        # "#{name}(#{THREAD_ID}##{count})" :
        set_thread_name.call("#{name} (#{WORKER_THREAD_ID}", ')')
      end
    end

    WORKERS_KEY = 'resque.workers'.freeze

    # register a worked id globally (for this application)
    def system_register_worker # :nodoc
      self.class.with_global_lock do
        workers = self.class.system_registered_workers.push(self.id)
        self.class.store_global_property(WORKERS_KEY, workers.join(','))
      end
    end

    # unregister a worked id globally
    def system_unregister_worker # :nodoc
      self.class.with_global_lock do
        workers = self.class.system_registered_workers
        workers.delete(self.id)
        self.class.store_global_property(WORKERS_KEY, workers.join(','))
      end
    end

    # returns all registered worker ids
    def self.system_registered_workers # :nodoc
      workers = fetch_global_property(WORKERS_KEY)
      ( workers || '' ).split(',')
    end

    # low-level API probably worth moving out of here :

    if defined?($servlet_context) && $servlet_context

      def self.fetch_global_property(key) # :nodoc
        with_global_lock do
          return $servlet_context.getAttribute(key)
        end
      end

      def self.store_global_property(key, value) # :nodoc
        with_global_lock do
          if value.nil?
            $servlet_context.removeAttribute(key)
          else
            $servlet_context.setAttribute(key, value)
          end
        end
      end

      def self.with_global_lock(&block) # :nodoc
        $servlet_context.synchronized(&block)
      end

    else # no $servlet_context assume 1 app within server/JVM (e.g. mizuno)

      def self.fetch_global_property(key) # :nodoc
        with_global_lock do
          return java.lang.System.getProperty(key)
        end
      end

      def self.store_global_property(key, value) # :nodoc
        with_global_lock do
          if value.nil?
            java.lang.System.clearProperty(key)
          else
            java.lang.System.setProperty(key, value)
          end
        end
      end

      def self.with_global_lock(&block) # :nodoc
        java.lang.System.java_class.synchronized(&block)
      end

    end

    def self.split_id(worker_id, split_thread = true)
      # thread name might contain ':' thus split it first :
      id = worker_id.split(/\[(.*?)\]/); thread = id.delete_at(1)
      host, pid, queues = id.join.split(':')
      split_thread ? [ host, pid, thread, queues ] : [ host, pid ,queues ]
    end

  end

  ( JRubyWorker::RESQUE_2x ? WorkerRegistry : Worker ).class_eval do
    # Returns a single worker object. Accepts a string id.
    def self.find(worker_id)
      if exists?(worker_id)
        # NOTE: a pack so that Resque::Worker.find returns
        # correct JRubyWorker class for thread-ed workers:
        host, pid, thread, queues = JRubyWorker.split_id(worker_id)
        queues_args = queues.split(',')
        queues_args = [ queues_args ] if JRubyWorker::RESQUE_2x
        if thread # "#{hostname}:#{pid}[#{thread_id}]:#{@queues.join(',')}"
          worker = JRubyWorker.new(*queues_args)
        else
          worker = Worker.new(*queues_args)
        end
        worker.to_s = worker_id
        worker
      else
        nil
      end
    end
  end

end
