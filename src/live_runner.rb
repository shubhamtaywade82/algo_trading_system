# frozen_string_literal: true

require_relative 'utils/config'
require_relative 'utils/logger'
require_relative 'utils/time_helpers'
require_relative 'utils/event_bus'
require_relative 'api/dhan_api_client'
require_relative 'api/websocket_feed'
require_relative 'market_data/tick_normalizer'
require_relative 'market_data/candle_aggregator'
require_relative 'strategies/trading_strategies'
require_relative 'execution/live_engine'

module AlgoTradingSystem
  # Orchestrates live trading session with real-time data and strategy execution
  class LiveRunner
    def initialize(strategy_name:, symbol:, env: 'paper', dependencies: {})
      Utils::Config.load!
      @symbol = symbol
      @env = env
      @strategy_name = strategy_name
      @dependencies = dependencies
      @event_bus = Utils::EventBus.instance

      setup_api
      setup_strategy
      setup_execution
      setup_aggregator
    end

    def start
      Utils::Logger.info('system.starting', env: @env, strategy: @strategy_name, symbol: @symbol)

      pre_load_historical_data

      @ws.connect
      # Subscribe to Index for Spot data and Option for trading
      # SecurityId 13 is NIFTY 50 Index
      @ws.subscribe([{ ExchangeSegment: 'NSE_FNO', SecurityId: '13' }])

      subscribe_to_events

      loop do
        sleep 1
        break if Utils::TimeHelpers.exit_window?
      end

      stop
    end

    def stop
      Utils::Logger.info('system.stopping')
      @ws.disconnect
    end

    private

    def pre_load_historical_data
      Utils::Logger.info('system.pre_loading_data', symbol: @symbol)

      # Fetch last 2 days of 1-min data to warm up indicators
      to_date = Date.today
      from_date = to_date - 2

      data = @api_client.fetch_intraday_history(
        security_id: '13', # NIFTY 50
        exchange_segment: 'NSE_FNO',
        instrument: 'INDEX',
        interval: '1',
        from_date: from_date,
        to_date: to_date
      )

      return unless data[:timestamp]

      # Convert to candles and feed to strategy
      data[:timestamp].each_with_index do |ts, i|
        candle = OpenStruct.new(
          timestamp: Time.at(ts),
          open: data[:open][i],
          high: data[:high][i],
          low: data[:low][i],
          close: data[:close][i],
          volume: data[:volume][i]
        )
        @strategy.add_bar(candle)
      end

      Utils::Logger.info('system.pre_load_complete', bar_count: data[:timestamp].size)
    end

    def setup_api
      client_id = ENV.fetch('DHAN_CLIENT_ID', 'test')
      token = ENV.fetch('DHAN_ACCESS_TOKEN', 'test')

      @api_client = @dependencies[:api_client] || Api::DhanApiClient.new(access_token: token)
      @ws = @dependencies[:ws_feed] || Api::WebsocketFeed.new(client_id: client_id, access_token: token)
    end

    def setup_strategy
      @strategy = @dependencies[:strategy] || TradingStrategies::StrategyFactory.create(@strategy_name)
    end

    def setup_execution
      @engine = @dependencies[:execution_engine] || Execution::LiveEngine.new(@api_client, @strategy, @symbol)
    end

    def setup_aggregator
      @aggregator = MarketData::CandleAggregator.new(interval_minutes: 1)
      @aggregator.on_candle_close do |candle|
        @engine.process_candle(candle)
      end
    end

    def subscribe_to_events
      @event_bus.subscribe('market_data.tick') do |payload|
        tick = MarketData::TickNormalizer.normalize(payload[:tick])
        @aggregator.process_tick(tick)
        @engine.process_tick(tick)
      end
    end
  end
end
