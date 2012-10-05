source "http://rubygems.org"

gem 'jruby-rack'

gem 'rake', :group => :test
gem 'test-unit', :group => :test
gem 'mocha', :group => :test

gem 'navvy', :group => :navvy

gem 'delayed_job', :group => :delayed_job

if ENV['delayed_job']
  if ENV['delayed_job'] == 'master'
    gem 'delayed_job', :git => 'git://github.com/collectiveidea/delayed_job.git', :group => :delayed_job
  else
    gem 'delayed_job', ENV['delayed_job'], :group => :delayed_job
  end
else
  gem 'delayed_job', :group => :delayed_job
end

if ENV['resque']
  if ENV['resque'] == 'master'
    gem 'resque', :git => 'git://github.com/defunkt/resque.git', :group => :resque
  else
    gem 'resque', ENV['resque'], :group => :resque
  end
else
  gem 'resque', :group => :resque
end
gem 'json', :group => :resque # NOTE: required since resque-1.23.0
