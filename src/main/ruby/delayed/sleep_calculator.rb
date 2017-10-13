module Delayed
  class JRubyWorker
    module SleepCalculator

      def sleep(time)
        Kernel.sleep calc_sleep_time(time)
      end

      private

      @@last = java.util.concurrent.atomic.AtomicLong.new

      def calc_sleep_time(time)
        count = thread_count rescue nil
        return time if ! count || count <= 1 || time <= 0

        last = @@last.get_and_set now = java.lang.System.current_time_millis
        return time if ( now - last ) > time * 1000

        # time / count.to_f - optimal pause time between threads
        diff = ( time / count.to_f ) - ( now - last ) * 0.001
        # converge to ~ pauses between worker threads (might add up to 10% to sleep time)
        diff > 0 ? ( time + diff / 5.0 ) : time
        # (now - last) * 0.001 < opt_pause ? ( time + time / 11.1 ) : time
      end

      def thread_count
        $worker_manager ? $worker_manager.thread_count : false
      end

    end
  end
end