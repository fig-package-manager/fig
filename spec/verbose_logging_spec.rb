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

  describe '.verbose' do
    it 'logs messages when verbose is enabled' do
      Fig::VerboseLogging.enable_verbose!
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      Fig::VerboseLogging.verbose('test message')
      
      log_content = @log_output.string
      expect(log_content).to include('[VERBOSE] test message')
    end

    it 'logs messages when debug logging is enabled (even without verbose flag)' do
      allow(Fig::Logging).to receive(:debug?).and_return(true)
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      Fig::VerboseLogging.verbose('test message')
      
      log_content = @log_output.string
      expect(log_content).to include('[VERBOSE] test message')
    end

    it 'does not log when neither verbose nor debug is enabled' do
      allow(Fig::Logging).to receive(:debug?).and_return(false)
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      Fig::VerboseLogging.verbose('test message')
      
      expect(@log_output.string).to be_empty
    end

    it 'falls back to stderr when logging is disabled but verbose is enabled' do
      Fig::VerboseLogging.enable_verbose!
      allow(Fig::Logging).to receive(:info?).and_return(false)
      
      Fig::VerboseLogging.verbose('test message')
      
      stderr_content = @stderr_output.string
      expect(stderr_content).to include('[VERBOSE] test message')
    end
  end

  describe '.should_log_verbose?' do
    it 'returns true when verbose is enabled' do
      Fig::VerboseLogging.enable_verbose!
      expect(Fig::VerboseLogging.should_log_verbose?).to be true
    end

    it 'returns true when debug logging is enabled' do
      allow(Fig::Logging).to receive(:debug?).and_return(true)
      expect(Fig::VerboseLogging.should_log_verbose?).to be true
    end

    it 'returns false when neither verbose nor debug is enabled' do
      allow(Fig::Logging).to receive(:debug?).and_return(false)
      expect(Fig::VerboseLogging.should_log_verbose?).to be false
    end
  end

  describe 'format helpers' do
    it 'formats durations correctly' do
      # Test private method via time_operation
      Fig::VerboseLogging.enable_verbose!
      allow(Fig::Logging).to receive(:info?).and_return(true)
      
      # Mock Process.clock_gettime to control duration
      start_time = 1000.0
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(start_time, start_time + 0.5)
      
      Fig::VerboseLogging.time_operation('test') { 'result' }
      
      log_content = @log_output.string
      expect(log_content).to include('500.0ms') # 0.5 seconds formatted as milliseconds
    end
  end
end
