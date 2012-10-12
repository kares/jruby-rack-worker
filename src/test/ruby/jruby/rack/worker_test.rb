require File.expand_path('test_helper', File.dirname(__FILE__) + '/../..')

module JRuby::Rack
  class WorkerTest < Test::Unit::TestCase

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
    
  end
end