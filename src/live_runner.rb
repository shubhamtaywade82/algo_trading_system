# frozen_string_literal: true

require_relative 'utils/config'
require_relative 'utils/logger'
require_relative 'utils/time_helpers'
require_relative 'api/dhan_api_client'
require_relative 'api/websocket_feed'
require_relative 'strategies/trading_strategies'

module AlgoTradingSystem
  # Orchestrates live trading session
  class LiveRunner
    def initialize(strategy_name:, symbol:, env: 'paper', dependencies: {})
      Utils::Config.load!
      @symbol = symbol
      @env = env
      @strategy_name = strategy_name
      @dependencies = dependencies

      setup_api
      setup_strategy
    end

    def start
      Utils::Logger.info('system.starting', env: @env, strategy: @strategy_name, symbol: @symbol)

      @ws.connect
      @ws.subscribe([{ ExchangeSegment: 'NSE_FNO', SecurityId: '13' }])

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

    def setup_api
      client_id = ENV.fetch('DHAN_CLIENT_ID', 'test')
      token = ENV.fetch('DHAN_ACCESS_TOKEN', 'test')

      @api_client = @dependencies[:api_client] || Api::DhanApiClient.new(access_token: token)
      @ws = @dependencies[:ws_feed] || Api::WebsocketFeed.new(client_id: client_id, access_token: token)
    end

    def setup_strategy
      @strategy = @dependencies[:strategy] || TradingStrategies::StrategyFactory.create(@strategy_name)
    end
  end
end
