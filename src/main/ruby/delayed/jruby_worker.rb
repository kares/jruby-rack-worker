require 'java'
require 'delayed_job' unless defined?(Delayed::Worker)

module Delayed

  # A JRuby DJ worker implementation.
  # - inspired by Delayed::Command
  # - no daemons dependency + thread-safe
  # @see #start_worker.rb
  class JRubyWorker < Worker
    
    def name
      if @name.nil?
        # super - [prefix]host:hostname pid:process_pid
        begin
          @name = "#{super} thread:#{thread_id}".freeze
        rescue
          @name = "#{@name_prefix}thread:#{thread_id}".freeze
        end
      end
      @name
    end
    
    def to_s; name; end
    
    def thread_id
      # NOTE: JRuby might set a bit long name for Thread.new { ... } code e.g.
      # RubyThread-1: /home/[...]/src/test/ruby/delayed/jruby_worker_test.rb:163
      if name = java.lang.Thread.currentThread.getName
        if name.size > 100 && match = name.match(/(.*?)\:\s.*?[\/\\]+/)
          match[1]
        else
          name
        end
      end
    end

    def exit!
      return if @exit # #stop?
      say "Stoping job worker"
      @exit = true # #stop
      if defined?(Delayed::Job) && Delayed::Job.respond_to?(:clear_locks!)
        Delayed::Job.clear_locks!(name)
      end
    end
    
    unless defined? Delayed::Lifecycle # DJ 2.x (< 3.0)
      require 'benchmark'
      # in case DJ 2.1 loads AS 3.x we're need `[1,2].sum` :
      require 'active_support/core_ext/enumerable' rescue nil
      
      def start
        say "Starting job worker"
        trap
        
        loop do
          result = nil

          realtime = Benchmark.realtime do
            result = work_off
          end

          count = result.sum

          break if @exit

          if count.zero?
            sleep(self.class.sleep_delay)
          else
            say "#{count} jobs processed at %.4f j/s, %d failed ..." % [count / realtime, result.last]
          end

          break if @exit
        end
      end
      
      def stop?; !!@exit; end
      def stop; @exit = true; end
      
    end
    
    protected
    
    def trap(name = nil)
      # catch invocations from #start traps TERM and INT
      at_exit { exit! } if ! name || name.to_s == 'TERM'
    end
    
  end

end

Dir.chdir( Rails.root ) if defined?(Rails.root) && Dir.getwd.to_s != Rails.root.to_s

if ! Delayed::Worker.backend && ! defined? Delayed::Lifecycle
  Delayed::Worker.guess_backend # deprecated on DJ since 3.0
end

# NOTE: no explicit logger configuration - DJ logger defaults to Rails.logger
# if this is not desired - e.g. one once script/delayed_job's logger behavior
# it's more correct to configure in an initializer rather then forcing the use
# of delayed_job.log (like Delayed::Command does) ...
#Delayed::Worker.logger = Logger.new(File.join(Rails.root, 'log', 'delayed_job.log'))

# NOTE: we skip Delayed::Worker's #before_fork and #after_fork and only execute
# the backend before/after fork hooks as there is no need to re-open files ...
Delayed::Worker.backend.before_fork if Delayed::Worker.backend
Delayed::Worker.backend.after_fork if Delayed::Worker.backend
