require 'delayed/threaded'

module Delayed
  JRubyWorker = Threaded::Worker unless const_defined?(:JRubyWorker)
end