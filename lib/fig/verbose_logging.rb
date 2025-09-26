# coding: utf-8

require 'fig/logging'

module Fig; end

# Core verbose logging infrastructure with timing support
module Fig::VerboseLogging
  @@verbose_enabled = false
  
  def self.enable_verbose!
    @@verbose_enabled = true
  end
  
  def self.disable_verbose!
    @@verbose_enabled = false
  end
  
  def self.verbose_enabled?
    @@verbose_enabled
  end
  
  def self.should_log_verbose?
    @@verbose_enabled || Fig::Logging.debug?
  end
  
  def self.verbose(message)
    return unless should_log_verbose?
    
    if Fig::Logging.info?
      Fig::Logging.info "[VERBOSE] #{message}"
    else
      # fallback to stderr if logging is completely disabled
      $stderr.puts "[VERBOSE] #{message}" if @@verbose_enabled
    end
  end
  
  def self.time_operation(operation_name, &block)
    return yield unless should_log_verbose?
    
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    verbose "starting #{operation_name}"
    
    begin
      result = yield
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      verbose "completed #{operation_name} in #{format_duration(duration)}"
      result
    rescue => error
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      verbose "failed #{operation_name} after #{format_duration(duration)}: #{error.class.name}: #{error.message}"
      raise
    end
  end
  
  def self.format_duration(seconds)
    if seconds < 1.0
      "#{(seconds * 1000).round(1)}ms"
    elsif seconds < 60.0
      "#{seconds.round(2)}s"
    else
      minutes = (seconds / 60).floor
      remaining_seconds = seconds - (minutes * 60)
      "#{minutes}m #{remaining_seconds.round(1)}s"
    end
  end
end
