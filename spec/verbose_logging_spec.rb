# coding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/verbose_logging'
require 'fig/logging'

describe 'Fig::VerboseLogging' do
  before(:each) do
    # Reset verbose state and capture output
    Fig::VerboseLogging.class_variable_set(:@@verbose_enabled, false)
    @log_output = StringIO.new
    @stderr_output = StringIO.new
    
    allow(Fig::Logging).to receive(:info) do |message|
      @log_output.puts(message) if Fig::Logging.info?
    end
    
    allow($stderr).to receive(:puts) do |message|
      @stderr_output.puts(message)
    end
  end

  describe '.time_operation' do
    it 'logs timing when verbose is enabled' do
      Fig::VerboseLogging.enable_verbose!
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      result = Fig::VerboseLogging.time_operation('test operation') do
        sleep(0.01) # Small delay to ensure measurable time
        'test result'
      end
      
      expect(result).to eq('test result')
      log_content = @log_output.string
      expect(log_content).to include('[VERBOSE] starting test operation')
      expect(log_content).to include('[VERBOSE] completed test operation in')
      expect(log_content).to match(/\d+(\.\d+)?ms/)
    end

    it 'logs timing when debug logging is enabled (even without verbose flag)' do
      allow(Fig::Logging).to receive(:debug?).and_return(true)
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      result = Fig::VerboseLogging.time_operation('test operation') do
        'test result'
      end
      
      expect(result).to eq('test result')
      log_content = @log_output.string
      expect(log_content).to include('[VERBOSE] starting test operation')
    end

    it 'does not log when neither verbose nor debug is enabled' do
      allow(Fig::Logging).to receive(:debug?).and_return(false)
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      result = Fig::VerboseLogging.time_operation('test operation') do
        'test result'
      end
      
      expect(result).to eq('test result')
      expect(@log_output.string).to be_empty
    end

    it 'falls back to stderr when logging is disabled but verbose is enabled' do
      Fig::VerboseLogging.enable_verbose!
      allow(Fig::Logging).to receive(:info?).and_return(false)
      
      result = Fig::VerboseLogging.time_operation('test operation') do
        'test result'
      end
      
      expect(result).to eq('test result')
      stderr_content = @stderr_output.string
      expect(stderr_content).to include('[VERBOSE] starting test operation')
    end

    it 'logs failure timing on exceptions' do
      Fig::VerboseLogging.enable_verbose!
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      expect do
        Fig::VerboseLogging.time_operation('failing operation') do
          raise StandardError, 'test error'
        end
      end.to raise_error(StandardError, 'test error')
      
      log_content = @log_output.string
      expect(log_content).to include('[VERBOSE] starting failing operation')
      expect(log_content).to include('[VERBOSE] failed failing operation after')
      expect(log_content).to include('StandardError: test error')
    end
  end

  describe '.log_dependency_resolution' do
    it 'logs dependency resolution with proper indentation when verbose is enabled' do
      Fig::VerboseLogging.enable_verbose!
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      Fig::VerboseLogging.log_dependency_resolution('mypackage', '1.0.0', 'default', 2)
      
      log_content = @log_output.string
      expect(log_content).to include('[VERBOSE]     resolving dependency: mypackage/1.0.0:default')
    end

    it 'skips logging for unnamed packages at root level' do
      Fig::VerboseLogging.enable_verbose!
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      Fig::VerboseLogging.log_dependency_resolution(nil, nil, 'default', 0)
      
      expect(@log_output.string).to be_empty
    end

    it 'does not log when neither verbose nor debug is enabled' do
      allow(Fig::Logging).to receive(:debug?).and_return(false)
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      Fig::VerboseLogging.log_dependency_resolution('mypackage', '1.0.0', 'default', 1)
      
      expect(@log_output.string).to be_empty
    end
  end

  describe '.log_repository_operation' do
    it 'logs repository operations with details when verbose is enabled' do
      Fig::VerboseLogging.enable_verbose!
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      Fig::VerboseLogging.log_repository_operation('download', 'http://example.com/repo', '5 packages')
      
      log_content = @log_output.string
      expect(log_content).to include('[VERBOSE] repository download: http://example.com/repo (5 packages)')
    end
  end

  describe '.log_asset_operation' do
    it 'logs asset operations with size formatting when verbose is enabled' do
      Fig::VerboseLogging.enable_verbose!
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      Fig::VerboseLogging.log_asset_operation('downloading', '/path/to/file.tar.gz', 1536)
      
      log_content = @log_output.string
      expect(log_content).to include('[VERBOSE] asset downloading: /path/to/file.tar.gz (1.5KB)')
    end
  end

  describe '.log_override_applied' do
    it 'logs override applications with proper indentation when verbose is enabled' do
      Fig::VerboseLogging.enable_verbose!
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      Fig::VerboseLogging.log_override_applied('mypackage', '1.0.0', '2.0.0', 1)
      
      log_content = @log_output.string
      expect(log_content).to include('[VERBOSE]   override applied: mypackage/1.0.0 -> mypackage/2.0.0')
    end

    it 'does not log when neither verbose nor debug is enabled' do
      allow(Fig::Logging).to receive(:debug?).and_return(false)
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      Fig::VerboseLogging.log_override_applied('mypackage', '1.0.0', '2.0.0', 0)
      
      expect(@log_output.string).to be_empty
    end
  end

  describe '.log_config_processing' do
    it 'logs config processing for named packages when verbose is enabled' do
      Fig::VerboseLogging.enable_verbose!
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      Fig::VerboseLogging.log_config_processing('mypackage', '1.0.0', 'default')
      
      log_content = @log_output.string
      expect(log_content).to include('[VERBOSE] processing config default for package mypackage/1.0.0')
    end

    it 'logs config processing for command-line packages when verbose is enabled' do
      Fig::VerboseLogging.enable_verbose!
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      Fig::VerboseLogging.log_config_processing(nil, nil, 'default')
      
      log_content = @log_output.string
      expect(log_content).to include('[VERBOSE] processing config default for command-line package')
    end
  end

  describe 'format helpers' do
    it 'formats durations correctly' do
      # Test private method via time_operation
      Fig::VerboseLogging.enable_verbose!
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      # Mock Time.now to control duration
      start_time = Time.now
      allow(Time).to receive(:now).and_return(start_time, start_time + 0.5)
      
      Fig::VerboseLogging.time_operation('test') { 'result' }
      
      log_content = @log_output.string
      expect(log_content).to include('500.0ms') # 0.5 seconds formatted as milliseconds
    end
  end
end
