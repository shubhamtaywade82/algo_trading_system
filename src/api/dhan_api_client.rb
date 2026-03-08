# frozen_string_literal: true

require 'faraday'
require 'json'
require 'date'

module Api
  # Fetches market data from DhanHQ V2 API
  # Supports Historical Daily, Intraday Minutes, and Expired Options
  class DhanApiClient
    BASE_URL = 'https://api.dhan.co'
    MAX_RETRIES = 3
    RETRY_INTERVAL = 1 # seconds

    def initialize(access_token:)
      @access_token = access_token
    end

    # Fetch 1, 5, 15, 25, 60 min candles (Last 5 years, max 90 days per request)
    def fetch_intraday_history(security_id:, exchange_segment:, instrument:, interval:, from_date:, to_date:)
      all_data = { timestamp: [], open: [], high: [], low: [], close: [], volume: [], open_interest: [] }
      
      # 90-day chunking for intraday
      split_date_range(from_date, to_date, chunk_size: 89).each do |chunk_from, chunk_to|
        payload = {
          securityId: security_id.to_s,
          exchangeSegment: exchange_segment,
          instrument: instrument,
          interval: interval.to_s,
          oi: true,
          fromDate: format_date_time(chunk_from, start_of_day: true),
          toDate: format_date_time(chunk_to, start_of_day: false)
        }
        
        response_data = post_with_retry('/v2/charts/intraday', payload)
        merge_flat_arrays(all_data, response_data)
      end
      
      all_data
    end

    # Fetch daily candles
    def fetch_daily_history(security_id:, exchange_segment:, instrument:, from_date:, to_date:)
      payload = {
        securityId: security_id.to_s,
        exchangeSegment: exchange_segment,
        instrument: instrument,
        expiryCode: 0,
        oi: true,
        fromDate: from_date.to_s,
        toDate: to_date.to_s
      }
      
      post_with_retry('/v2/charts/historical', payload)
    end

    # Legacy/Specific for expired options backtesting
    def fetch_expired_options(underlying: :nifty, from_date:, to_date:, interval: '1', option_type: 'CALL', strikes: ['ATM'], expiry_flag: 'WEEK', expiry_code: 0)
      security_id = map_underlying_id(underlying)
      all_data = {}

      split_date_range(from_date, to_date, chunk_size: 29).each do |chunk_from, chunk_to|
        strikes.each do |strike|
          payload = {
            'exchangeSegment' => security_id == 1 ? 'BSE_FNO' : 'NSE_FNO',
            'interval' => interval.to_s,
            'securityId' => security_id.to_s,
            'instrument' => 'OPTIDX',
            'expiryFlag' => expiry_flag,
            'expiryCode' => expiry_code.to_i,
            'strike' => strike,
            'drvOptionType' => option_type,
            'requiredData' => %w[open high low close iv oi volume spot],
            'fromDate' => chunk_from.to_s,
            'toDate' => chunk_to.to_s
          }
          
          response = post_with_retry('/v2/charts/rollingoption', payload)
          strike_data = response.dig(:data, option_type.downcase.to_sym)
          next unless strike_data

          strike_key = "#{strike}_#{option_type}"
          all_data[strike_key] ||= { timestamp: [], open: [], high: [], low: [], close: [], iv: [], oi: [], volume: [], spot: [] }
          
          merge_strike_data(all_data[strike_key], strike_data)
        end
      end

      all_data
    end

    private

    def map_underlying_id(underlying)
      { nifty: 13, banknifty: 12, finnifty: 27, sensex: 1 }.fetch(underlying.to_sym)
    end

    def post_with_retry(path, payload)
      retries = 0
      begin
        response = connection.post(path) do |req|
          req.body = payload.to_json
        end

        if response.success?
          return JSON.parse(response.body, symbolize_names: true)
        elsif response.status == 429 && retries < MAX_RETRIES
          raise Faraday::RetriableResponse, "Rate limit hit"
        else
          Utils::Logger.error("api.request_failed", status: response.status, body: response.body, path: path)
        end
        {}
      rescue Faraday::RetriableResponse, Faraday::Error => e
        Utils::Logger.error("api.connection_error", error: e.message, path: path)
        if retries < MAX_RETRIES
          sleep(RETRY_INTERVAL * (2**retries))
          retries += 1
          retry
        end
        {}
      end
    end

    def merge_flat_arrays(target, source)
      return unless source.is_a?(Hash)
      %i[timestamp open high low close volume open_interest].each do |key|
        target[key].concat(source[key] || []) if source[key]
      end
    end

    def merge_strike_data(target, source)
      %i[timestamp open high low close iv oi volume spot].each do |key|
        target[key].concat(source[key] || []) if source[key]
      end
    end

    def split_date_range(from, to, chunk_size:)
      ranges = []
      current = Date.parse(from.to_s)
      target = Date.parse(to.to_s)
      while current <= target
        chunk_to = [current + chunk_size, target].min
        ranges << [current, chunk_to]
        current = chunk_to + 1
      end
      ranges
    end

    def format_date_time(date, start_of_day:)
      time_str = start_of_day ? "09:15:00" : "15:30:00"
      "#{date} #{time_str}"
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.headers['access-token'] = @access_token
        f.headers['Content-Type'] = 'application/json'
        f.headers['Accept'] = 'application/json'
        f.adapter Faraday.default_adapter
      end
    end
  end
end

module Faraday
  class RetriableResponse < Error; end
end
