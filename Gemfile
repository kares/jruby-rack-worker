source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem 'jruby-rack'
gem 'rack', '< 2', :require => nil if JRUBY_VERSION < '9.0'

group :test do
  gem 'rake', '< 12', :require => nil
  gem 'test-unit', '~> 2.5.3'
  gem 'test-unit-context'
  gem 'mocha'
end

group :delayed_job do

  if ENV['delayed_job']
    if ENV['delayed_job'] == 'master'
      gem 'delayed_job', :git => 'git://github.com/collectiveidea/delayed_job.git'
      gem 'delayed_job_active_record', :require => nil
    else
      gem 'delayed_job', version = ENV['delayed_job']
      unless version =~ /~?\s?2\.\d/ # delayed_job_active_record only for DJ >= 3.0
        gem 'delayed_job_active_record', :require => nil
      end
      if version =~ /~?\s?4\.[1]/ # add_dependency "delayed_job", ">= 4.1"
        gem 'delayed_cron_job', :require => nil
      end
    end
  else
    gem 'delayed_job'
    gem 'delayed_job_active_record', :require => nil
    gem 'delayed_cron_job', :require => nil
  end

  if ENV['activerecord']
    gem 'activerecord', version = ENV['activerecord'], :require => nil
    if version =~ /~?\s?4\.[12]/
      gem 'activerecord-jdbc-adapter', '~> 1.3.20', :require => nil, :platform => :jruby
    else
      gem 'activerecord-jdbc-adapter', :require => nil, :platform => :jruby
    end
  else
    gem 'activerecord', :require => nil # for tests
    gem 'activerecord-jdbc-adapter', :require => nil, :platform => :jruby
  end
  gem 'jdbc-sqlite3', '~> 3.20.1', :platform => :jruby

  gem 'delayed-threaded', :require => false

end

group :resque do

  if version = ENV['resque']
    if version == 'master'
      gem 'resque', :git => 'git://github.com/resque/resque.git'
    else
      gem 'resque', version
    end
  else
    gem 'resque'
  end

  gem 'redis', '< 4', :require => nil if JRUBY_VERSION < '9.0'

  gem 'json', :require => false # NOTE: required since resque-1.23.0

end
