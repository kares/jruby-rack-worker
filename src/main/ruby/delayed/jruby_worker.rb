require 'java'
require 'delayed/worker' unless defined?(Delayed::Worker)

module Delayed

  # A JRuby DJ worker implementation.
  # - inspired by Delayed::Command
  # - no daemons dependency + thread-safe
  # @see #start_worker.rb
  class JRubyWorker < Worker
    
    def name
      return @name unless @name.nil?
      prefix = "#{@name_prefix}host:#{Socket.gethostname} pid:#{Process.pid} " rescue "#{@name_prefix}"
      @name = "#{prefix}thread:#{java.lang.Thread.currentThread.getName}".freeze
    end
    
    def start
      say "starting #{self.class.name}[#{name}] ..."
      super
    end

    def exit!
      return if @exit # #stop?
      say "exiting #{self.class.name}[#{name}] ..."
      @exit = true # #stop
      Delayed::Job.clear_locks!(name) if Delayed::Job.respond_to?(:clear_locks!)
    end
    
    protected
    
    def trap(name)
      # catch traps from #start :
      #trap('TERM') { say 'Exiting...'; stop }
      #trap('INT') { say 'Exiting...'; stop }
      at_exit { exit! } if name.to_s == 'TERM'
    end
    
  end

end

Delayed::Worker.guess_backend unless Delayed::Worker.backend

Delayed::Worker.backend.before_fork if Delayed::Worker.backend

Dir.chdir( Rails.root ) if defined?(Rails.root) && Dir.getwd != Rails.root
# NOTE: no explicit logger configuration - DJ logger defaults to Rails.logger
# if this is not desired - e.g. one once script/delayed_job's logger behavior
# it's more correct to configure in an initializer rather then forcing the use
# of delayed_job.log (like Delayed::Command does) ...
#Delayed::Worker.logger = Logger.new(File.join(Rails.root, 'log', 'delayed_job.log'))

Delayed::Worker.backend.after_fork if Delayed::Worker.backend
