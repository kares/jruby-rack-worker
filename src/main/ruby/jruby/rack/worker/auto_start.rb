if defined?(::Delayed::Worker)
  load 'delayed/start_worker.rb'
elsif defined?(::Navvy::Worker)
  load 'navvy/start_worker.rb'
else
  clazz = org.kares.jruby.rack.WorkerContextListener
  raise "could not auto start worker consider setting: " +
  "'#{clazz::SCRIPT_KEY}' or '#{clazz::SCRIPT_PATH_KEY}' context-param"
end