require "youtube-rb"
require "webmock/rspec"
require "tmpdir"
require "fileutils"

# Allow connections to stubbed URLs only
WebMock.disable_net_connect!(allow_localhost: false)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Load support files
  Dir[File.join(__dir__, "support", "**", "*.rb")].sort.each { |f| require f }

  # Clean up test downloads before each test
  config.before(:each) do
    @test_output_dir = Dir.mktmpdir('youtube-rb-test')
  end

  config.after(:each) do
    FileUtils.rm_rf(@test_output_dir) if @test_output_dir && Dir.exist?(@test_output_dir)
  end
end
