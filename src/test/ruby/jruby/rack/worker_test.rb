require File.expand_path('test_helper', File.dirname(__FILE__) + '/../..')

module JRuby::Rack
  class WorkerTest < Test::Unit::TestCase

    def self.startup
      require 'jruby/rack/worker/env'
      JRuby::Rack::Worker.load_jar
    end
    
    test "VERSION is defined" do
      assert defined?(JRuby::Rack::Worker::VERSION)
      assert_false JRuby::Rack::Worker::VERSION.frozen?
    end
    
    test "JAR_PATH is defined relatively" do
      assert defined?(JRuby::Rack::Worker::JAR_PATH)
      version = JRuby::Rack::Worker::VERSION
      jar_path = "src/main/ruby/jruby-rack-worker_#{version}.jar"
      assert_equal File.expand_path(jar_path), JRuby::Rack::Worker::JAR_PATH
    end
    
    context :ENV do
      
      test "resolves key when set" do
        assert ! JRuby::Rack::Worker::ENV.key?(:foo)
        assert_nil JRuby::Rack::Worker::ENV[:foo]
        
        JRuby::Rack::Worker::ENV['foo'] = 'bar'
        assert_not_nil JRuby::Rack::Worker::ENV['foo']
        assert_equal 'bar', JRuby::Rack::Worker::ENV['foo']
        assert_equal 'bar', JRuby::Rack::Worker::ENV[:foo]
      end
      
      test "resolves key from ENV" do
        begin
          ::ENV['BAR'] = '42'
          
          assert_equal '42', JRuby::Rack::Worker::ENV['BAR']
          JRuby::Rack::Worker::ENV['BAR'] = 'BINARY-BAR'
          assert_equal '42', ::ENV['BAR']
        ensure
          ::ENV.delete('BAR')
        end
      end

      test "resolves key from worker manager" do
        servlet_context = mock('servet_context')
        servlet_context.expects(:getInitParameter).with('PARAM').returns 'VAL'
        servlet_context.stubs(:getServletContextName).returns nil
        begin
          $worker_manager = org.kares.jruby.rack.DefaultWorkerManager.new(servlet_context)
          
          assert_equal 'VAL', JRuby::Rack::Worker::ENV['PARAM']
        ensure
          $worker_manager = nil
        end
      end
      
    end
    
  end
end