require 'resque' unless defined?(Resque::Worker)

module Resque
  
  class JRubyWorker < Worker
    
    def initialize(*queues)
      super
      @cant_fork = true
    end
    
    # similar to resque's original pruning but thread-based
    def prune_dead_workers
      all_workers = Worker.all
      known_workers = worker_threads unless all_workers.empty?
      all_workers.each do |worker|
        uuid, thread, queues = worker.id.split(':')
        next unless uuid == hostuuid
        next if known_workers.include?(thread)
        log! "Pruning dead worker: #{worker}"
        worker.unregister_worker
      end
    end

    # returns worker thread names that supposely belong to the current application
    def worker_threads
      thread_group = java.lang.Thread.currentThread.getThreadGroup
      thread_class = java.lang.Thread.java_class
      threads = java.lang.reflect.Array.newInstance(thread_class, thread_group.activeCount)
      thread_group.enumerate(threads)
      # NOTE: we shall check the name from $servlet_context.getServletContextName
      # but that's an implementation detail of the initialize currently that threads
      # are named including their context name. however thread group should be fine
      threads.map do |thread| 
        name_id = org.kares.jruby.rack.WorkerThreadFactory::NAME_ID
        thread && thread.getName.index(name_id) ? thread.getName : nil
      end.compact
    end
    
    # makes no sense to be used here
    def worker_pids
      nil
    end
    
    # reserve changed since version 1.20.0
    RESERVE_ARG = instance_method(:reserve).arity > 0 # :nodoc
    
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
        
        if job = RESERVE_ARG ? reserve(interval) : reserve
          log "got: #{job.inspect}"
          job.worker = self
          run_hook :before_fork, job
          working_on job

          procline "Processing #{job.queue} since #{Time.now.to_i}"
          perform(job, &block)

          done_working
        else
          break if interval.zero?
          if RESERVE_ARG
            log! "Sleeping for #{interval} seconds"
            procline paused? ? "Paused" : "Waiting for #{@queues.join(',')}"
            sleep interval            
          else
            log! "Timed out after #{interval} seconds"
            procline paused? ? "Paused" : "Waiting for #{@queues.join(',')}"
          end
        end
      end

    ensure
      unregister_worker
    end
    
    # no forking with JRuby
    def fork
      @cant_fork = true
      nil # important due #work
    end

    # we're definitely not REE
    def enable_gc_optimizations
      nil
    end
    
    # Runs all the methods needed when a worker begins its lifecycle.
    def startup
      # we do not register_signal_handlers
      prune_dead_workers
      run_hook :before_first_fork
      register_worker
    end

    def pause
      # trap('CONT') makes no sense here
      sleep(1.0)
    end
    
    def pause_processing
      log "pausing job processing"
      @paused = true
    end
    
    def inspect
      "#<JRubyWorker #{to_s}>"
    end
    
    def to_s
      @to_s ||= "#{hostuuid}:#{java.lang.Thread.currentThread.getName}:#{@queues.join(',')}".freeze
    end
    alias_method :id, :to_s
    
    def hostuuid
      self.class.global_uuid
    end
    
    def pid
      # we do not rely on pids thus do not fail ever
      Process.pid rescue nil
    end
    
    def register_worker
      outcome = super
      system_register_worker
      outcome
    end
    
    def unregister_worker
      system_unregister_worker
      super
    end
    
    def procline(string = nil)
      # do not change $0 as this method otherwise would ...
      if string.nil?
        @procline # and act as a reader if no argument given
      else
        log! @procline = "resque-#{Resque::Version}: #{string}"
      end
    end

    # Log a message to STDOUT if we are verbose or very_verbose.
    def log(message)
      if verbose
        logdev.puts "*** #{message}"
      elsif very_verbose
        time = Time.now.strftime('%H:%M:%S %Y-%m-%d')
        name = java.lang.Thread.currentThread.getName
        logdev.puts "** [#{time}] #{name}: #{message}"
      end
    end
    
    public
    
    def logdev
      # resque compatibility - stdout puts by default
      @logdev ||= STDOUT
    end
    
    def logdev=(logdev)
      @logdev = logdev
    end
    
    private
    
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
    
    if defined?($serlet_context) && $serlet_context

      def self.fetch_global_property(key) # :nodoc
        with_global_lock do
          return $serlet_context.getAttribute(key)
        end
      end

      def self.store_global_property(key, value) # :nodoc
        with_global_lock do
          if value.nil?
            $serlet_context.removeAttribute(key)
          else
            $serlet_context.setAttribute(key, value)
          end
        end
      end

      def self.with_global_lock(&block) # :nodoc
        $serlet_context.synchronized(&block)
      end
      
    else
      
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
    
    UUID_KEY = 'resque.uuid'.freeze
    
    # returns a unique identifier value for this JVM
    # 
    # a single value per JVM is fine ... it will be added to the hostname
    # to support cases when 2 JVMs run on a single host and thus we're able
    # to distinguish them (we won't touch workers from the othe process)
    def self.global_uuid # :nodoc
      uuid = java.lang.System.getProperty(UUID_KEY)
      unless uuid
        java.lang.System.java_class.synchronized do 
          uuid = java.lang.System.getProperty(UUID_KEY)
          unless uuid
            uuid = java.util.UUID.randomUUID.toString[0...18].gsub('-', '')
            java.lang.System.setProperty(UUID_KEY, uuid)
          end
        end
      end
      uuid # e.g. "6cf793450cbb4999"
    end
    
  end
end
