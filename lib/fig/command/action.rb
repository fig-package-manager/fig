module Fig; end
class Fig::Command; end

module Fig::Command::Action
  attr_writer :execution_context

  def primary_option()
    return options()[0]
  end

  def options()
    raise NotImplementedError
  end

  # Is this a special Action that should just be run on its own without looking
  # at other Actions?  Note that anything that returns true won't get an
  # execution context.
  def execute_immediately_after_command_line_parse?
    return false
  end

  def descriptor_requirement()
    raise NotImplementedError
  end

  def allow_both_descriptor_and_file?()
    return false
  end

  def need_base_package?()
    raise NotImplementedError
  end

  def base_package_can_come_from_descriptor?()
    return true
  end

  def need_base_config?()
    raise NotImplementedError
  end

  def register_base_package?()
    raise NotImplementedError
  end

  def apply_config?()
    raise NotImplementedError
  end

  def apply_base_config?()
    raise NotImplementedError
  end

  # Slurp data out of command-line options.
  def configure(options)
    # Do nothing by default.
    return
  end

  def execute()
    raise NotImplementedError
  end
end
