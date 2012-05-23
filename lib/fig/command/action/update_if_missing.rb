require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::UpdateIfMissing
  include Fig::Command::Action::Role::HasNoSubAction

  def options
    return %w<--update-if-missing>
  end

  def descriptor_action()
    return nil
  end

  def need_base_package?()
    return true
  end

  def need_base_config?()
    return true
  end

  def register_base_package?()
    return true
  end

  def apply_base_config?()
    return true
  end
end
