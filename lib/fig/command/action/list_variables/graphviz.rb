# coding: utf-8

require 'fig/command/action'
require 'fig/command/action/role/list_as_graphviz'
require 'fig/command/action/role/list_base_config'
require 'fig/command/action/role/list_variables_as_graphviz'
require 'fig/command/action/role/list_walking_dependency_tree'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
class   Fig::Command::Action::ListVariables; end

class Fig::Command::Action::ListVariables::Graphviz
  include Fig::Command::Action
  include Fig::Command::Action::Role::ListAsGraphviz
  include Fig::Command::Action::Role::ListBaseConfig
  include Fig::Command::Action::Role::ListVariablesAsGraphviz
  include Fig::Command::Action::Role::ListWalkingDependencyTree

  def options()
    return %w<--list-variables --graphviz>
  end
end
