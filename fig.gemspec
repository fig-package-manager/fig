require 'rake'
require 'rake/file_list'

require_relative 'lib/fig/version'

Gem::Specification.new do |spec|
  spec.name = 'fig'
  spec.version = Fig::VERSION
  spec.email = 'maintainer@figpackagemanager.org'
  spec.authors = 'Fig Folks'
  spec.platform = Gem::Platform::RUBY
  spec.license = 'BSD-3-Clause'

  spec.required_ruby_version = '>= 3.1.0'

  spec.summary     =
    'Utility for configuring environments and managing dependencies across a team of developers.'
  spec.description =
    "Fig is a utility for configuring environments and managing dependencies across a team of developers. Given a list of packages and a command to run, Fig builds environment variables named in those packages (e.g., CLASSPATH), then executes the command in that environment. The caller's environment is not affected."

  spec.add_dependency 'bcrypt_pbkdf', '>= 1.1.0'
  spec.add_dependency 'colorize',          '>= 0.5.8'
  spec.add_dependency 'ed25519', '>= 1.2.4'
  spec.add_dependency 'highline',          '>= 1.6.19'
  spec.add_dependency 'json',              '>= 1.8' # why is this here and not Gemfile
  spec.add_dependency 'ffi-libarchive-binary', '~> 0.3.0'
  spec.add_dependency 'log4r',             '>= 1.1.5'
  spec.add_dependency 'net-ftp', '>= 0.1.3'
  spec.add_dependency 'net-netrc',         '>= 0.2.2'
  spec.add_dependency 'net-sftp',          '>= 2.1.2'
  spec.add_dependency 'net-ssh',           '>= 6.1.0'
  spec.add_dependency 'rdoc',              '>= 6.3.1'
  spec.add_dependency 'treetop',           '>= 1.4.14'
  spec.add_dependency 'base64', '>= 0.1.1'

  spec.add_development_dependency 'bundler',         '>= 2.6.1'
  spec.add_development_dependency 'rake',            '~> 13.0'
  spec.add_development_dependency 'rspec',           '~> 3'
  spec.add_development_dependency 'simplecov',       '>= 0.6.2'
  spec.add_development_dependency 'simplecov-html',  '>= 0.5.3'

  spec.executables = ['fig']

  # spec.files gets computed in Rakefile after loading
  # because we have generated files.
end

