lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "coinbase_exchange/version"

Gem::Specification.new do |spec|
  spec.name          = "coinbase_exchange"
  spec.version       = CoinbaseExchange::VERSION
  spec.authors       = ["Dmitry Kontsevoy"]
  spec.email         = ["dmitry@yep.by"]

  spec.summary       = %q{Access the Coinbase exchange rate data.}
  spec.description   = %q{CoinbaseExchange extends Money::Bank::Base and gives you access to the current Coinbase exchange rates.}
  spec.homepage      = "https://github.com/h3xby/coinbase_exchange"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "money", "~> 6.7"

  spec.add_development_dependency "bundler", ">= 2.2.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "vcr", "~> 4.0"
  spec.add_development_dependency "webmock", "~> 3.1"
  spec.add_development_dependency "faraday", "~> 0.13"
  spec.add_development_dependency "timecop", "~> 0.9"
  spec.add_development_dependency "byebug"
end
