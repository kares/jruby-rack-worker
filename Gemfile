source "https://rubygems.org"

gem 'jruby-rack'

group :test do
  gem 'rake'
  gem 'test-unit'
  gem 'test-unit-context'
  gem 'mocha'
end

group :delayed_job do
  if ENV['delayed_job']
    if ENV['delayed_job'] == 'master'
      gem 'delayed_job', :git => 'git://github.com/collectiveidea/delayed_job.git'
    else
      gem 'delayed_job', ENV['delayed_job']
    end
  else
    gem 'delayed_job'
  end
  # TODO this stands in our way of testing with 2.x :
  gem 'delayed_job_active_record', :require => nil # for tests
  gem 'activerecord', :require => nil # for tests
  gem 'activerecord-jdbcsqlite3-adapter', :require => nil # for tests
end

group :resque do
  if ENV['resque']
    if ENV['resque'] == 'master'
      gem 'resque', :git => 'git://github.com/defunkt/resque.git'
    else
      gem 'resque', ENV['resque']
    end
  else
    gem 'resque'
  end
  gem 'json' # NOTE: required since resque-1.23.0
end

gem 'navvy', :group => :navvy