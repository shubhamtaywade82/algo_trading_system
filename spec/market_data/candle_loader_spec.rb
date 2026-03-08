# frozen_string_literal: true

require 'spec_helper'
require_relative '../../src/market_data/candle_loader'

RSpec.describe MarketData::CandleLoader do
  describe '.load_history' do
    let(:symbol) { 'NIFTY' }
    let(:from_time) { Time.parse('2024-01-01T09:15:00+05:30') }
    let(:to_time) { Time.parse('2024-01-01T09:25:00+05:30') }

    it 'loads candles from csv fixture' do
      candles = described_class.load_history(symbol: symbol, from_time: from_time, to_time: to_time, timeframe: '5m', source: :csv)
      expect(candles.size).to eq(3)
      expect(candles.first.open).to eq(21500.0)
      expect(candles.first.symbol).to eq('NIFTY')
      expect(candles.last.close).to eq(21590.0)
    end

    it 'filters candles by time range' do
      filtered_from = Time.parse('2024-01-01T09:20:00+05:30')
      candles = described_class.load_history(symbol: symbol, from_time: filtered_from, to_time: to_time, timeframe: '5m', source: :csv)
      expect(candles.size).to eq(2)
      expect(candles.first.timestamp).to eq(filtered_from)
    end
  end
end
