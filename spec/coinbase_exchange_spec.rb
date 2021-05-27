require 'money'
require 'money/bank/coinbase_exchange'

vcr_options = { cassette_name: 'coinbase', match_requests_on: %i[method uri body] }
RSpec.describe "CoinbaseExchange", vcr: vcr_options do
  it "has a version number" do
    expect(CoinbaseExchange::VERSION).not_to be nil
  end

  let(:bank) { Money::Bank::CoinbaseExchange.new }

  it "should accept a ttl_in_seconds option" do
    Money::Bank::CoinbaseExchange.ttl_in_seconds = 86400
    expect(Money::Bank::CoinbaseExchange.ttl_in_seconds).to eq(86400)
  end

  describe ".refresh_rates_expiration!" do
    it "set the #rates_expiration using the TTL and the current time" do
      Money::Bank::CoinbaseExchange.ttl_in_seconds = 86400
      new_time = Time.now
      Timecop.freeze(new_time)
      Money::Bank::CoinbaseExchange.refresh_rates_expiration!
      expect(Money::Bank::CoinbaseExchange.rates_expiration).to eq(new_time + 86400)
    end
  end

  describe "#flush_rate" do
    it "should remove a specific rate from @rates" do
      bank.get_rate('USD', 'BTC')
      bank.get_rate('BTC', 'EUR')
      bank.flush_rate('USD', 'BTC')
      expect(bank.store.instance_variable_get("@rates")).to include('BTC_TO_EUR')
      expect(bank.store.instance_variable_get("@rates")).to_not include('USD_TO_BTC')
    end
  end

  describe "#expire_rates" do
    before do
      Money::Bank::CoinbaseExchange.ttl_in_seconds = 1000
    end

    context "when the ttl has expired" do
      before do
        new_time = Time.now + 1001
        Timecop.freeze(new_time)
      end

      it "should flush all rates" do
        expect(bank).to receive(:flush_rates)
        bank.expire_rates
      end

      it "updates the next expiration time" do
        exp_time = Time.now + 1000

        bank.expire_rates
        expect(Money::Bank::CoinbaseExchange.rates_expiration).to eq(exp_time)
      end
    end

    context "when the ttl has not expired" do
      it "not should flush all rates" do
        expect(bank).to_not receive(:flush_rates)
        bank.expire_rates
      end
    end
  end

  describe '#get_rate' do
    it "should try to expire the rates" do
      expect(bank).to receive(:expire_rates).once
      bank.get_rate('USD', 'USD')
    end

    it "should use #fetch_rate when rate is unknown" do
      expect(bank).to receive(:fetch_rate).once
      bank.get_rate('USD', 'USD')
    end

    it "should not use #fetch_rate when rate is known" do
      bank.get_rate('BTC', 'USD')
      expect(bank).to_not receive(:fetch_rate)
      bank.get_rate('BTC', 'USD')
    end

    it "should return the correct rate" do
      expect(bank.get_rate('USD', 'USD')).to eq(1.0)
    end

    it "should store the rate for faster retreival" do
      bank.get_rate('USD', 'BTC')
      expect(bank.store.instance_variable_get("@rates")).to include('USD_TO_BTC')
    end

    it "should raise UnknownRate error when rate is not known" do
      WebMock.stub_request(:get, 'https://api.coinbase.com/v2/exchange-rates')
        .with(query: 'currency=BTC')
        .to_return(status: 400,
                   headers: { 'content-type' => 'application/json' },
                   body: '{"errors":[{"id":"invalid_request","message":"Invalid currency (BTC)"}]}')

      expect {
        bank.get_rate('BTC', 'USD')
      }.to raise_error(Money::Bank::UnknownRate)
    end

    it "should raise CoinbaseExchangeFetchError there is an unknown issue with extracting the exchange rate" do
      WebMock.stub_request(:get, 'https://api.coinbase.com/v2/exchange-rates')
        .with(query: 'currency=USD')
        .to_return(status: 500)
      expect {
        bank.get_rate('USD', 'BTC')
      }.to raise_error(Money::Bank::CoinbaseExchangeFetchError)
    end
  end
end
