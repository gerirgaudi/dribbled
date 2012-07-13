require 'singleton'
require 'log4r'

module Dribbled

  class Logger

    include Singleton

    attr_reader :log

    def initialize
      @log = Log4r::Logger.new("dribbled")
      @log.add Log4r::StderrOutputter.new('console', :formatter => Log4r::PatternFormatter.new(:pattern => "%c [%l] %m"), :level => Log4r::DEBUG)
    end

  end
end