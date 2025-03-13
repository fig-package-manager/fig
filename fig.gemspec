# coding: utf-8
require_relative 'lib/fig/version'
require_relative 'lib/git_helper'

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

  sha1 = GitHelper.sha1
  if sha1
    spec.metadata['git_sha'] = sha1
    
    built = "Built from git SHA1: #{sha1}"
    spec.summary += " #{built}"
    spec.description += "\n\n#{built}"
  end

  spec.add_dependency 'bcrypt_pbkdf', '~> 1.1.0'
  spec.add_dependency 'colorize',          '~> 1.1.0'
  spec.add_dependency 'ed25519', '~> 1.3.0'
  spec.add_dependency 'highline',          '~> 3.1.0'
  spec.add_dependency 'json',              '~> 2.10.0'
  spec.add_dependency 'ffi-libarchive-binary', '~> 0.3.0'
  spec.add_dependency 'log4r',             '~> 1.1.0'
  spec.add_dependency 'net-ftp', '~> 0.3.0'
  spec.add_dependency 'net-netrc',         '~> 0.2.0'
  spec.add_dependency 'net-sftp',          '~> 4.0.0'
  spec.add_dependency 'net-ssh',           '~> 7.3.0'
  spec.add_dependency 'treetop',           '~> 1.6.0'
  spec.add_dependency 'base64', '~> 0.2.0'
  spec.add_dependency 'stringio', '~> 3.1.0'
  spec.add_dependency 'bundler',         '~> 2.6.0'

  spec.add_development_dependency 'rdoc',              '~> 6.12.0'
  spec.add_development_dependency 'rake',            '~> 13.2.0'
  spec.add_development_dependency 'rspec',           '~> 3'
  spec.add_development_dependency 'simplecov',       '~> 0.22.0'
  spec.add_development_dependency 'simplecov-html',  '~> 0.13.0'

  spec.executables = ['fig']
  spec.require_paths = ['lib']

  # spec.files gets computed in Rakefile after loading
  # because we have generated files.
end

