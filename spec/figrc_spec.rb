# coding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'stringio'
require 'tempfile'

require 'fig/figrc'
require 'fig/operating_system'
require 'fig/repository'
require 'fig/working_directory_maintainer'

describe 'FigRC' do
  def create_override_file(foo, bar = nil)
    tempfile = Tempfile.new('some_json_tempfile')
    tempfile << %Q< { "foo" : "#{foo}" >
    if not bar.nil?
      tempfile << %Q< , "bar" : "#{bar}" >
    end
    tempfile << %Q< } >
    tempfile.close
    return tempfile
  end

  def create_override_file_with_repository_url()
    tempfile = Tempfile.new('some_json_tempfile')
    tempfile << %Q< { "default FIG_CONSUME_URL" : "#{FIG_CONSUME_URL}", "default FIG_PUBLISH_URL" : "#{FIG_PUBLISH_URL}" } >
    tempfile.close
    return tempfile
  end

  def create_remote_config(foo, bar = nil)
    FileUtils.mkdir_p(
      File.join(FIG_CONSUME_DIR, Fig::Repository::METADATA_SUBDIRECTORY)
    )
    figrc_path = File.join(FIG_CONSUME_DIR, Fig::FigRC::REPOSITORY_CONFIGURATION)
    file_handle = File.new(figrc_path,'w')
    file_handle.write( %Q< { "foo" : "#{foo}" > )
    if not bar.nil?
      file_handle.write( %Q< , "bar" : "#{bar}" > )
    end
    file_handle.write( %Q< } > )
    file_handle.close
    return
  end

  def invoke_find(override_path, consume_repository_url, publish_repository_url = nil)
    return Fig::FigRC.find(
      override_path,
      consume_repository_url,
      publish_repository_url,
      Fig::OperatingSystem.new(false),
      FIG_HOME,
      true
    )
  end

  before(:all) do
    clean_up_test_environment
    set_up_test_environment
  end

  after(:each) do
    clean_up_test_environment
  end

  it 'handles override path with a remote repository' do
    tempfile = create_override_file('loaded as override')

    create_remote_config("loaded from repository (shouldn't be)")
    configuration = invoke_find tempfile.path, FIG_CONSUME_URL, FIG_PUBLISH_URL
    tempfile.unlink

    configuration['foo'].should == 'loaded as override'
  end

  it 'handles no override, no repository (full stop)' do
    configuration = invoke_find nil, nil
    configuration['foo'].should == nil
  end

  it 'handles no override, repository specified as the empty string' do
    configuration = invoke_find nil, ''
    configuration['foo'].should == nil
  end

  it 'handles no override, repository specified as whitespace' do
    configuration = invoke_find nil, " \n\t"
    configuration['foo'].should == nil
  end

  it 'handles no repository config and no override specified, and config does NOT exist on server' do
    configuration = invoke_find nil, 'file:///does_not_exist/'
    configuration['foo'].should == nil
  end

  it 'retrieves configuration from repository with no override' do
    create_remote_config('loaded from repository')

    configuration = invoke_find nil, FIG_CONSUME_URL
    configuration['foo'].should == 'loaded from repository'
  end

  it 'has a remote config but gets its config from the override file provided' do
    create_remote_config('loaded from remote repository')
    tempfile = create_override_file('loaded as override to override remote config')
    configuration = invoke_find tempfile.path, FIG_CONSUME_URL
    configuration['foo'].should == 'loaded as override to override remote config'
  end

  it 'merges override file config over remote config' do
    create_remote_config('loaded from remote repository', 'should not be overwritten')
    tempfile = create_override_file('loaded as override to override remote config')
    configuration = invoke_find tempfile.path, FIG_CONSUME_URL, FIG_PUBLISH_URL
    configuration['foo'].should == 'loaded as override to override remote config'
    configuration['bar'].should == 'should not be overwritten'
  end

  it 'retrieves configuration from repository specified by override file' do
    tempfile = create_override_file_with_repository_url
    create_remote_config('loaded from repository')

    configuration = invoke_find tempfile.path, nil, nil
    configuration['foo'].should == 'loaded from repository'
  end

  it 'ignores unknown settings without errors' do
    tempfile = Tempfile.new('unknown_settings_test')
    tempfile << %Q< { "foo": "bar", "fig_2x_setting": "future setting value" } >
    tempfile.close

    # This should not raise any errors despite unknown setting
    configuration = invoke_find(tempfile.path, nil)
    
    # Known setting works
    configuration['foo'].should == 'bar'
    
    # Unknown setting is accessible but would be ignored by code not looking for it
    configuration['fig_2x_setting'].should == 'future setting value'
    
    # Completely nonexistent setting returns nil
    configuration['nonexistent'].should be_nil
  end
end
