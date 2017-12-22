require 'money'
require 'money/rates_store/rate_removal_support'
require 'faraday'
require 'json'

class Money
  module Bank
    # Raised when there is an unexpected error in extracting exchange rates
    # from Coinbase
    class CoinbaseExchangeFetchError < Error
    end

    class CoinbaseExchange < Money::Bank::VariableExchange
      class << self
        # @return [Integer] Returns the Time To Live (TTL) in seconds.
        attr_reader :ttl_in_seconds

        # @return [Time] Returns the time when the rates expire.
        attr_reader :rates_expiration

        ##
        # Set the Time To Live (TTL) in seconds.
        #
        # @param [Integer] the seconds between an expiration and another.
        def ttl_in_seconds=(value)
          @ttl_in_seconds = value
          refresh_rates_expiration! if ttl_in_seconds
        end

        ##
        # Set the rates expiration TTL seconds from the current time.
        #
        # @return [Time] The next expiration.
        def refresh_rates_expiration!
          @rates_expiration = Time.now + ttl_in_seconds
        end
      end

      attr_reader :client

      def initialize(*)
        super
        @client = Faraday.new(url: "https://api.coinbase.com/v2/") do |b|
          b.adapter Faraday.default_adapter
        end
        @store.extend Money::RatesStore::RateRemovalSupport
      end

      ##
      # Clears all rates stored in @rates
      #
      # @return [Hash] The empty @rates Hash.
      #
      # @example
      #   @bank = CoinbaseExchange.new  #=> <Money::Bank::CoinbaseExchange...>
      #   @bank.get_rate(:USD, :EUR)  #=> 0.776337241
      #   @bank.flush_rates           #=> {}
      def flush_rates
        store.clear_rates
      end

      ##
      # Clears the specified rate stored in @rates.
      #
      # @param [String, Symbol, Currency] from Currency to convert from (used
      #   for key into @rates).
      # @param [String, Symbol, Currency] to Currency to convert to (used for
      #   key into @rates).
      #
      # @return [Float] The flushed rate.
      #
      # @example
      #   @bank = CoinbaseExchange.new    #=> <Money::Bank::CoinbaseExchange...>
      #   @bank.get_rate(:USD, :EUR)    #=> 0.776337241
      #   @bank.flush_rate(:USD, :EUR)  #=> 0.776337241
      def flush_rate(from, to)
        store.remove_rate(from, to)
      end

      ##
      # Returns the requested rate.
      #
      # It also flushes all the rates when and if they are expired.
      #
      # @param [String, Symbol, Currency] from Currency to convert from
      # @param [String, Symbol, Currency] to Currency to convert to
      #
      # @return [Float] The requested rate.
      #
      # @example
      #   @bank = CoinbaseExchange.new  #=> <Money::Bank::CoinbaseExchange...>
      #   @bank.get_rate(:USD, :EUR)  #=> 0.776337241
      def get_rate(from, to)
        expire_rates
        store.get_rate(from, to) || store.add_rate(from, to, fetch_rate(from, to))
      end

      ##
      # Flushes all the rates if they are expired.
      #
      # @return [Boolean]
      def expire_rates
        if self.class.ttl_in_seconds && self.class.rates_expiration <= Time.now
          flush_rates
          self.class.refresh_rates_expiration!
          true
        else
          false
        end
      end

      protected

      ##
      # Queries for the exchange rates for currency and returns it
      #
      # @param [String, Symbol, Currency] currency Currency to fetch
      #
      # @return [Hash] The requested rates.
      def fetch_exchange_rates(currency)
        resp = client.get('exchange-rates', { currency: currency })

        case resp.status
        when 200 then JSON.parse(resp.body).dig('data', 'rates')
        when 404 then raise Money::Bank::UnknownRate
        when 400
          if resp.headers['content-type'].start_with?('application/json')
            errors = JSON.parse(resp.body)&.dig('errors')
            if errors&.first&.dig('message')&.start_with?('Invalid currency')
              raise Money::Bank::UnknownRate
            end
          end

          raise CoinbaseExchangeFetchError
        else
          raise CoinbaseExchangeFetchError
        end
      rescue Faraday::Error, JSON::ParserError
        raise CoinbaseExchangeFetchError
      end

      ##
      # Queries for the requested rate and returns it.
      #
      # @param [String, Symbol, Currency] from Currency to convert from
      # @param [String, Symbol, Currency] to Currency to convert to
      #
      # @return [BigDecimal] The requested rate.
      def fetch_rate(from, to)
        from = Money::Currency.wrap(from)
        to = Money::Currency.wrap(to)
        rates = fetch_exchange_rates(from.iso_code)
        rate = rates.dig(to.iso_code)

        raise Money::Bank::UnknownRate unless rate && rate != ""

        rate.to_f
      end
    end
  end
end