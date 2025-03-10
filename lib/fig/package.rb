# coding: utf-8

require 'fig/logging'
require 'fig/no_such_package_config_error'
require 'fig/package_descriptor'
require 'fig/statement/archive'
require 'fig/statement/configuration'
require 'fig/statement/include'
require 'fig/statement/include_file'
require 'fig/statement/resource'
require 'fig/statement/retrieve'

module Fig; end

# The parsed representation of a configuration file for a specific version.
# Contains the statement objects.
#
# Unique identifier for this object: name and version. A different version of
# the same package will be a separate instance of this class.
class Fig::Package
  include Comparable

  DEFAULT_CONFIG  = 'default'

  attr_reader   :name
  attr_reader   :version
  attr_reader   :file_path
  attr_reader   :description
  attr_reader   :runtime_directory
  attr_reader   :include_file_base_directory
  attr_reader   :statements
  attr_accessor :backtrace
  attr_accessor :unparsed_text

  def initialize(
    name,
    version,
    file_path,
    description,
    runtime_directory,
    include_file_base_directory,
    statements,
    synthetic
  )
    @name                         = name
    @version                      = version
    @file_path                    = file_path
    @description                  = description
    @runtime_directory            = runtime_directory
    @include_file_base_directory  = include_file_base_directory
    @statements                   = statements
    @synthetic                    = synthetic
    @applied_config_names         = []
    @backtrace                    = nil
  end

  # Was this package (supposedly) created from something other than usual
  # parsing?  (Note that some tests artificially create "non-synthetic"
  # instances.)
  def synthetic?
    return @synthetic
  end

  # Is this the base package?
  def base?()
    return @base
  end

  def set_base(yea_or_nay)
    @base = yea_or_nay

    return
  end

  def [](config_name)
    @statements.each do
      |statement|

      return statement if
            statement.is_a?(Fig::Statement::Configuration) \
        &&  statement.name == config_name
    end

    descriptor = Fig::PackageDescriptor.new(
      @name,
      @version,
      config_name,
      :file_path   => @file_path,
      :description => @description
    )
    config_description = nil
    if @name.nil? and @version.nil?
      config_description = config_name
    else
      config_description = descriptor.to_string(:use_default_config)
    end

    message = %Q<There is no "#{config_description}" config.>

    raise Fig::NoSuchPackageConfigError.new(message, descriptor, self)
  end

  def <=>(other)
    return if not other
    return if synthetic?
    return if other.synthetic?

    if (
          not name              \
      and not other.name        \
      and not description       \
      and not other.description
    )
      compared = compare_components(file_path, other.file_path)
    else
      compared = compare_components(name, other.name)
    end
    return compared if compared != 0

    return compare_components(version, other.version)
  end

  def configs
    return @statements.select { |statement| statement.is_a?(Fig::Statement::Configuration) }
  end

  def config_names
    return configs.collect { |statement| statement.name }
  end

  def retrieves
    return @statements.select { |statement| statement.is_a?(Fig::Statement::Retrieve) }
  end

  def archive_locations
    return @statements.
      select{|s| s.is_a?(Fig::Statement::Archive)}.
      map{|s| s.location}
  end

  def resource_locations
    return @statements.
      select{|s| s.is_a?(Fig::Statement::Resource)}.
      map{|s| s.location}
  end

  def applied_config_names()
    return @applied_config_names.clone
  end

  def add_applied_config_name(name)
    @applied_config_names << name
  end

  def primary_config_name()
    return @applied_config_names.first
  end

  # Returns an array of PackageDescriptors
  def package_dependencies(config_name, backtrace)
    descriptors = []

    self[config_name || DEFAULT_CONFIG].walk_statements do
      |statement|

      if statement.is_a?(Fig::Statement::Include)
        descriptors << statement.resolved_dependency_descriptor(self, backtrace)
      elsif statement.is_a?(Fig::Statement::IncludeFile)
        full_path = statement.full_path_relative_to self

        descriptors << Fig::PackageDescriptor.new(
          nil, nil, statement.config_name, :file_path => full_path
        )
      elsif statement.is_a?(Fig::Statement::Override)
        backtrace.add_override(statement)
      end
    end

    return descriptors
  end

  # Block will receive a Statement.
  def walk_statements(&block)
    @statements.each do |statement|
      yield statement
      statement.walk_statements(&block)
    end

    return
  end

  def name_or_file_or_description
    return @name if @name

    if @file_path
      return "[#{@file_path}]"
    end

    return "<#{@description}>"
  end

  def to_s
    name    = name_or_file_or_description
    version = @version || '<empty>'
    return Fig::PackageDescriptor.format(name, version, nil)
  end

  def to_s_with_config(config_name)
    displayed_config = config_name == DEFAULT_CONFIG ? nil : config_name
    return Fig::PackageDescriptor.format(
      name_or_file_or_description, version, displayed_config
    )
  end

  # Useful for debugging; should not be used for regular output.
  def to_descriptive_string_with_config(config_name)
    return Fig::PackageDescriptor.format(
      name_or_file_or_description, version, config_name, :use_default_config, description
    )
  end


  private

  def compare_components(mine, others)
    if mine.nil?
      if others.nil?
        return 0
      end

      return 1
    end

    if others.nil?
      return -1
    end

    return mine <=> others
  end
end
