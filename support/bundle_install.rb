require 'bundler'
require 'stringio'
require 'rbconfig'

# capture standard output
def capture_stdout
  orig_stdout = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = orig_stdout
end

def override_toolchain_from_env(tools=%w[ CC CPP CXX LD AS ])
  tools.each do |tool|
    if ENV.key?(tool)
      RbConfig::MAKEFILE_CONFIG[tool] = ENV[tool]
      puts "Injecting #{tool}=#{ENV[tool]} from environment."
    end
  end
end

def install_and_capture_native_gems
  native_gems = []

  out = capture_stdout do
    begin
      override_toolchain_from_env
      Bundler.reset!
      bundle_def = Bundler::Definition.build('Gemfile', 'Gemfile.lock', nil)
      installer = Bundler::Installer.install(Bundler.root, bundle_def)
    rescue Bundler::BundlerError => e
      puts e.message
      exit 1
    end
  end

  out.each_line do |line|
    if line =~ /Installing (.*) (.*) with native extensions/
      native_gems << { name: $1, version: $2 }
    end
  end

  return native_gems, out
end

native_gems, installer_output = install_and_capture_native_gems

puts installer_output

puts "\n\nGems with native extensions:"
if native_gems.empty?
  puts 'No native gems.'
else
  native_gems.each { |gem| puts "  #{gem[:name]}" }
end
