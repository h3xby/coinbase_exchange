require 'webmock'
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.default_cassette_options = {
    record: ENV['CI'] ? :none : :new_episodes
  }
  config.ignore_request do |request|
    uri = URI(request.uri)
    [
      'localhost', '127.0.0.1'
    ].include?(uri.host)
  end
end
