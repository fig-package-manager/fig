# coding: utf-8
require 'fileutils'
require 'rdoc/task'
require 'rspec/core/rake_task'
require 'rubygems'
require 'rubygems/package_task'
require 'treetop'

include FileUtils

treetop_grammars  = FileList['lib/fig/**/*.treetop']
COMPILED_GRAMMARS = treetop_grammars.ext('rb')

def load_gemspec(specname = 'fig.gemspec')
  spec = Gem::Specification.load(specname)

  spec.files = FileList[
    * %w[
         BUGS.md
         Changes
         bin/*
         lib/**/*
         LICENSE
         README.md
         ]
  ].to_a + COMPILED_GRAMMARS

  spec
end

def main()
  task :default => :rspec

  rule '.rb' => '.treetop' do
    |task|

    puts "Generating code from #{task.source} into #{task.name}."
    Treetop::Compiler::GrammarCompiler.new.compile(task.source, task.name)
  end

  desc 'Compile Treetop grammars'
  task :treetop   => COMPILED_GRAMMARS
  task :gem       => [:treetop]
  task :rspec     => [:treetop]
  task :simplecov => [:treetop]


  fig_gemspec = load_gemspec
  
  Gem::PackageTask.new(fig_gemspec).define

  desc 'Alias for the gem task.'
  task :build => :gem


  desc 'Run RSpec tests.'
  RSpec::Core::RakeTask.new(:rspec) do |spec|
    # Order is randomized so that we find inter-test dependencies.
    spec.rspec_opts = []
    spec.rspec_opts << '--order rand'
  end
  task :rspec do
    clean_up_after_testing()
  end

  desc 'Run RSpec tests with SimpleCov.'
  task :simplecov do
    ENV['FIG_COVERAGE'] = 'true'
  end
  RSpec::Core::RakeTask.new(:simplecov) do |spec|
    # Don't use '--order rand' like the standard "rspec" task so that generated
    # SimpleCov command-names are consistent between runs.

    # If you're attempting to test SimpleCov configuration, it helps to
    # restrict RSpec to a subset of the tests.  Uncomment the line below and
    # edit to the regex that you want.
    #spec.pattern = 'spec/figrc_spec.rb'
  end
  task :simplecov do
    clean_up_after_testing()
  end

  desc 'Create zip file of SimpleCov output.'
  task :simplecov_archive => [:simplecov]
  task :simplecov_archive do
    Dir.chdir('coverage') do
      create_zip(
        '../coverage.zip', Dir.entries('.') - %w[ . .. .resultset.json ]
      )
    end
  end


  desc 'Tag the release, push the tag to the "origin" remote repository, and publish the rubygem to rubygems.org.'
  task :publish do
    if local_repo_up_to_date?
      require_relative 'lib/fig/version'
      version = Foo::VERSION
      if push_to_rubygems(version)
        tag_and_push_to_git(version)
      end
    end
  end


  RDoc::Task.new do |rdoc|
    rdoc.rdoc_dir = 'rdoc'
    rdoc.title = "fig #{Fig::VERSION}"
    rdoc.rdoc_files.include('README*')
    rdoc.rdoc_files.include('lib/**/*.rb')
  end


  desc 'Remove build products and temporary files.'
  task :clean do
    [
      %w[ coverage coverage.zip pkg rdoc resources.tar.gz spec/runtime-work ],
      COMPILED_GRAMMARS
    ].flatten.each do
      |path|
      rm_rf "./#{path}"
    end
  end

  desc 'Create tags files for editors using ctags.'
  task :ctags do
    system 'ctags', * %w[
      --exclude=lib/fig/grammar/*.rb
      --extra=+f
      --fields=+afikKlmnsSzt
      --langmap=ruby:+.treetop
      --recurse
      --totals
    ]
  end

  return
end


def git_working_directory_clean?
  return %x<git ls-files --deleted --modified --others --exclude-standard> == ''
end

def tag_exists_in_local_repo?(new_tag)
  tag_exists = false
  tag_list = %x<git tag>
  tags = tag_list.split("\n")
  tags.each do |tag|
    if tag.chomp == new_tag
      tag_exists = true
    end
  end

  return tag_exists
end

def create_git_tag(version)
  new_tag = "v#{version}"
  print "Checking for an existing #{new_tag} git tag... "
  if not tag_exists_in_local_repo?(new_tag)
    puts 'Tag does not already exist.'
    puts "Creating #{new_tag} tag."
    %x<git tag #{new_tag}>
  else
    puts 'Tag exists.'
    return nil
  end

  if not tag_exists_in_local_repo?(new_tag)
    puts "The tag was not successfully created. Aborting!"
    return nil
  end

  return new_tag
end

def push_to_remote_repo(new_tag)
  if new_tag != nil
    puts %Q<Pushing #{new_tag} tag to "origin" remote repository.>
    %x<git push origin #{new_tag}>
  end

  return
end

def tag_and_push_to_git(version)
  new_tag = nil
  if git_working_directory_clean?
    new_tag = create_git_tag(version)
    push_to_remote_repo(new_tag)
  else
    puts 'Cannot proceed with tag, push, and publish because your environment is not clean.'
    puts 'The status of your local git repository:'
    puts %x{git status 2>&1}
  end

  return new_tag != nil
end

def local_repo_up_to_date?
  pull_results = %x{git pull 2>&1}
  if pull_results.chomp != "Already up-to-date."
    puts 'The local repository was not up-to-date:'
    puts pull_results
    puts 'Publish aborted.'

    return false
  end

  return true
end

def push_to_rubygems(version)
  print "Checking to see if pkg/fig-#{version}.gem exists... "
  if File.exist?("pkg/fig-#{version}.gem")
    puts 'File exists'
    puts "Pushing pkg/fig-#{version}.gem to rubygems.org."
    puts %x{gem push pkg/fig-#{version}.gem 2>&1}

    return true
  else
    puts 'File does not exist.'
    puts 'Please build the gem before publishing.'

    return false
  end

  return
end

def create_zip(path, file_names)
  rm_rf path
  system 'zip', '-r', '-9', '-q', path, *file_names

  # libarchivestatic doesn't support zip files currently
  # Archive.write_open_filename(
  #   path, Archive::COMPRESSION_COMPRESS, Archive::FORMAT_ZIP
  # ) do
  #   |writer|

  #   file_names.each do
  #     |file_name|

  #     writer.new_entry do
  #       |entry|

  #       entry.pathname = file_name
  #       writer.write_header(entry)

  #       if entry.regular?
  #         writer.write_data(
  #           open(file_name) { |reader| reader.binmode; reader.read }
  #         )
  #       end
  #     end
  #   end
  # end

  return
end

def clean_up_after_testing()
  rm_rf './.fig'

  return
end


main()
