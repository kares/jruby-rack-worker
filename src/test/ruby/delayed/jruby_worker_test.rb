require File.expand_path('test_helper', File.dirname(__FILE__) + '/..')
require 'delayed/jruby_worker'

module Delayed
  class JRubyWorkerTest < Test::Unit::TestCase
    
    startup do
      JRuby::Rack::Worker.load_jar
    end

    test "new works with a hash" do
      assert_nothing_raised do 
        Delayed::JRubyWorker.new({})
      end
    end

    test "name includes thread name" do
      name = java.lang.Thread.currentThread.name
      assert_match /#{name}/, new_worker.name
    end

    test "name can be changed and reset" do
      worker = new_worker
      assert_not_nil worker.name
      worker.name = 'foo-bar'
      assert_equal 'foo-bar', worker.name
      worker.name = nil
      assert_match /^host:.*?thread:.*?/, worker.name
    end
    
    test "loops on start" do
      worker = new_worker
      worker.expects(:loop).once
      worker.start
    end
    
    test "traps (signals) on start" do
      worker = new_worker
      worker.expects(:trap).at_least_once
      worker.stubs(:loop)
      worker.start
      
      assert_equal worker.class, new_worker.method(:trap).owner
    end

    test "sets up an at_exit hook on start" do
      worker = new_worker
      worker.stubs(:loop)
      worker.expects(:at_exit).once
      worker.start
    end

    test "exit worker from at_exist registered hook" do
      worker = new_worker
      def worker.at_exit(&block)
        @_at_exit_block = block
      end
      def worker.call_at_exit
        @_at_exit_block.call
      end
      worker.stubs(:loop)
      
      worker.start
      assert ! worker.stop?
      stub_Delayed_Job
      worker.call_at_exit
      assert_true worker.stop?
    end
    
    test "name is made of [prefix] host pid and thread" do
      worker = nil; lock = java.lang.Object.new
      thread = java.lang.Thread.new do
        begin
          worker = new_worker
          worker.name_prefix = 'PREFIX '
          worker.name
        ensure
          lock.synchronized { lock.notify }
        end
      end
      thread.name = 'worker_2'
      thread.start
      lock.synchronized { lock.wait }
      
      # prefix host pid thread
      parts = worker.name.split(' ')
      assert_equal 4, parts.length, parts.inspect
      require 'socket'
      assert_equal 'PREFIX', parts[0]
      assert_equal 'host:' + Socket.gethostname, parts[1]
      assert_equal 'pid:' + Process.pid.to_s, parts[2]
      assert_equal 'thread:worker_2', parts[3]
    end
    
    test "to_s is worker name" do
      worker = new_worker
      worker.name_prefix = '42'
      assert_equal worker.name, worker.to_s
    end
    
    private
    
    def stub_Delayed_Job
      Delayed.const_set :Job, const = mock('Delayed::Job')
      const
    end
    
    teardown do
      if job = Delayed::Job && defined? Mocha
        Delayed.remove_const :Job if job.is_a?(Mocha::Mock)
      end
    end
    
    private
    
    def new_worker(options = {})
      Delayed::JRubyWorker.new options
    end
    
  end
end