require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::Clean
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<--clean>
  end

  def descriptor_requirement()
    return :required
  end

  def modifies_repository?()
    return true
  end

  def load_base_package?()
    return false
  end

  def configure(options)
    @descriptor = options.descriptor
  end

  def execute()
    @execution_context.repository.clean(@descriptor)

    return EXIT_SUCCESS
  end
end
