require 'bundler/setup'
require 'fig/version'
require 'fig/command'

Fig::Command.new.run_fig_with_exception_handling ARGV
