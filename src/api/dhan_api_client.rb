# frozen_string_literal: true

require 'faraday'
require 'json'
require 'date'

module Api
  # Fetches expired options data from DhanHQ V2 API
  # Returns data in hash-of-arrays format compatible with OptionsBacktestOrchestrator
  class DhanApiClient
    BASE_URL = 'https://api.dhan.co/v2'
    MAX_RETRIES = 3
    RETRY_INTERVAL = 1 # seconds

    def initialize(access_token:)
      @access_token = access_token
    end

    def fetch_expired_options(
      underlying: :nifty,
      from_date:,
      to_date:,
      interval: '1',
      option_type: 'CALL',
      strikes: ['ATM'],
      expiry_flag: 'WEEK',
      expiry_code: 0
    )
      security_id = map_security_id(underlying)
      all_data = {}

      split_date_range(from_date, to_date).each do |chunk_from, chunk_to|
        strikes.each do |strike|
          response_data = request_with_retry(
            security_id: security_id,
            from: chunk_from,
            to: chunk_to,
            interval: interval,
            type: option_type,
            strike: strike,
            expiry_flag: expiry_flag,
            expiry_code: expiry_code
          )
          
          strike_data = response_data.dig(:data, option_type.downcase.to_sym)
          next unless strike_data

          strike_key = "#{strike}_#{option_type}"
          all_data[strike_key] ||= {
            timestamp: [], open: [], high: [], low: [], close: [],
            iv: [], oi: [], volume: [], spot: []
          }
          
          merge_strike_data(all_data[strike_key], strike_data)
        end
      end

      all_data
    end

    private

    def map_security_id(underlying)
      { nifty: 13, banknifty: 12, finnifty: 27, sensex: 1 }.fetch(underlying.to_sym)
    end

    def request_with_retry(p)
      retries = 0
      begin
        response = connection.post('/charts/rollingoption') do |req|
          req.body = {
            exchangeSegment: p[:security_id] == 1 ? 'BSE_FNO' : 'NSE_FNO',
            interval: p[:interval],
            securityId: p[:security_id],
            instrument: 'OPTIDX',
            expiryFlag: p[:expiry_flag],
            expiryCode: p[:expiry_code],
            strike: p[:strike],
            drvOptionType: p[:type],
            requiredData: %w[open high low close iv oi volume spot],
            fromDate: p[:from].to_s,
            toDate: p[:to].to_s
          }.to_json
        end

        if response.success?
          return JSON.parse(response.body, symbolize_names: true)
        elsif response.status == 429 && retries < MAX_RETRIES
          raise Faraday::RetriableResponse, "Rate limit hit"
        end
        {}
      rescue Faraday::RetriableResponse, Faraday::Error
        if retries < MAX_RETRIES
          sleep(RETRY_INTERVAL * (2**retries))
          retries += 1
          retry
        end
        {}
      end
    end

    def merge_strike_data(target, source)
      %i[timestamp open high low close iv oi volume spot].each do |key|
        target[key].concat(source[key] || [])
      end
    end

    def split_date_range(from, to)
      ranges = []
      current = Date.parse(from.to_s)
      target = Date.parse(to.to_s)
      while current <= target
        chunk_to = [current + 29, target].min
        ranges << [current, chunk_to]
        current = chunk_to + 1
      end
      ranges
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.headers['access-token'] = @access_token
        f.headers['Content-Type'] = 'application/json'
        f.adapter Faraday.default_adapter
      end
    end
  end
end

module Faraday
  class RetriableResponse < Error; end
end
