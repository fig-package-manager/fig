# coding: utf-8

require 'fig/logging'

module Fig; end

# Enhanced logging with timing for verbose operations
module Fig::VerboseLogging
  @@verbose_enabled = false
  
  def self.enable_verbose!
    @@verbose_enabled = true
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
    
    start_time = Time.now
    verbose "starting #{operation_name}"
    
    begin
      result = yield
      duration = Time.now - start_time
      verbose "completed #{operation_name} in #{format_duration(duration)}"
      result
    rescue => error
      duration = Time.now - start_time
      verbose "failed #{operation_name} after #{format_duration(duration)}: #{error.class.name}: #{error.message}"
      raise
    end
  end
  
  def self.log_dependency_resolution(package_name, version, config, depth)
    return unless should_log_verbose?
    
    # Skip logging for synthetic/unnamed packages 
    return if package_name.nil? || package_name.empty?
    
    indent = "  " * depth
    version_str = version || "<no version>"
    config_str = config || "default"
    verbose "#{indent}resolving dependency: #{package_name}/#{version_str}:#{config_str}"
  end
  
  def self.log_package_include(package_descriptor, depth)
    return unless should_log_verbose?
    
    # Skip logging for synthetic/unnamed packages at root level
    if depth == 0 && package_descriptor.respond_to?(:name) && 
       (package_descriptor.name.nil? || package_descriptor.name.empty?)
      return
    end
    
    indent = "  " * depth
    if package_descriptor.respond_to?(:to_string)
      descriptor_string = package_descriptor.to_string
    elsif package_descriptor.respond_to?(:name) && package_descriptor.respond_to?(:version)
      name = package_descriptor.name || "<unnamed>"
      version = package_descriptor.version || "<no version>"
      config = package_descriptor.config || "default"
      descriptor_string = "#{name}/#{version}:#{config}"
    else
      descriptor_string = package_descriptor.to_s
    end
    verbose "#{indent}including package: #{descriptor_string}"
  end
  
  def self.log_override_applied(package_name, original_version, override_version, depth)
    return unless should_log_verbose?
    
    indent = "  " * depth
    verbose "#{indent}override applied: #{package_name}/#{original_version} -> #{package_name}/#{override_version}"
  end
  
  def self.log_config_processing(package_name, version, config_name)
    return unless should_log_verbose?
    
    if package_name && !package_name.empty?
      verbose "processing config #{config_name} for package #{package_name}/#{version || '<no version>'}"
    else
      verbose "processing config #{config_name} for command-line package"
    end
  end
  
  def self.log_repository_operation(operation, url_or_path, details = nil)
    return unless should_log_verbose?
    
    message = "repository #{operation}: #{url_or_path}"
    message += " (#{details})" if details
    verbose message
  end
  
  def self.log_asset_operation(operation, asset_path, size_bytes = nil)
    return unless should_log_verbose?
    
    message = "asset #{operation}: #{asset_path}"
    message += " (#{format_bytes(size_bytes)})" if size_bytes
    verbose message
  end
  
  private
  
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
  
  def self.format_bytes(bytes)
    return "unknown size" unless bytes
    
    if bytes < 1024
      "#{bytes}B"
    elsif bytes < 1024 * 1024
      "#{(bytes / 1024.0).round(1)}KB"
    elsif bytes < 1024 * 1024 * 1024
      "#{(bytes / (1024.0 * 1024)).round(1)}MB"
    else
      "#{(bytes / (1024.0 * 1024 * 1024)).round(1)}GB"
    end
  end
end
