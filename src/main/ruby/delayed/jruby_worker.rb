
require 'delayed/worker' unless defined?(Delayed::Worker)

module Delayed

  # A JRuby DJ worker implementation.
  # - inspired by Delayed::Command
  # - no daemons dependency + thread-safe
  # @see #start_worker.rb
  class JRubyWorker < Worker

    def start
      say "starting #{Delayed::JRubyWorker}[#{name}] ..."

      at_exit { exit! }

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
      @exit
    end

    def exit!
      return if @exit
      say "exiting #{Delayed::JRubyWorker}[#{name}] ..."
      @exit = true
      Delayed::Job.clear_locks!(name)
    end

  end

end

Delayed::Worker.guess_backend unless Delayed::Worker.backend

Delayed::Worker.backend.before_fork

Dir.chdir( Rails.root ) if defined?(Rails.root) && Dir.getwd != Rails.root
# NOTE: no explicit logger configuration - DJ logger defaults to Rails.logger
# if this is not desired - e.g. one once script/delayed_job's logger behavior
# it's more correct to configure in an initializer rather then forcing the use
# of delayed_job.log (like Delayed::Command does) ...
#Delayed::Worker.logger = Logger.new(File.join(Rails.root, 'log', 'delayed_job.log'))

Delayed::Worker.backend.after_fork
