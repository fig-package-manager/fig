require 'bundler'
require 'stringio'

# capture standard output
def capture_stdout
  orig_stdout = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = orig_stdout
end

def install_and_capture_native_gems
  native_gems = []

  out = capture_stdout do
    begin
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

if native_gems.empty?
  puts 'No native gems.'
else
  native_gems.each { |gem| puts gem[:name] }
end
