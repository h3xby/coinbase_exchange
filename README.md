# CoinbaseExchange

This gem extends Money::Bank::VariableExchange with Money::Bank::CoinbaseExchange
and gives you access to the current Coinbase exchange rates.

## Usage

```ruby
require 'money'
require 'money/bank/coinbase_exchange'

# (optional)
# set the seconds after than the current rates are automatically expired
# by default, they never expire
Money::Bank::CoinbaseExchange.ttl_in_seconds = 86400

# set default bank to instance of GoogleCurrency
Money.default_bank = Money::Bank::CoinbaseExchange.new

# create a new money object, and use the standard #exchange_to method
money = Money.new(1_00, "USD") # amount is in cents
money.exchange_to(:EUR)

# or install and use the 'monetize' gem
require 'monetize'
money = 1.to_money(:USD)
money.exchange_to(:EUR)
```

An UnknownRate will be thrown if #exchange_to is called with a Currency that Money knows, but Coinbase does not.

An UnknownCurrency will be thrown if #exchange_to is called with a Currency that Money does not know.

A CoinbaseExchangeFetchError will be thrown if there is an unknown issue with the Coinbase API.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
