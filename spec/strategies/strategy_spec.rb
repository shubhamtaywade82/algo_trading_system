# frozen_string_literal: true

require 'spec_helper'
require 'time'
require_relative '../../src/strategies/ema_crossover'
require_relative '../../src/strategies/orb_strategy'
require_relative '../../src/strategies/vix_spike_strategy'

RSpec.describe Strategies do
  let(:candle_struct) { Struct.new(:timestamp, :high, :low, :close) }

  describe Strategies::EmaCrossover do
    it 'signals buy when fast EMA > slow EMA and RSI > threshold' do
      strategy = described_class.new
      
      ema_fast = double('ema_fast', ready?: true, value: 100)
      ema_slow = double('ema_slow', ready?: true, value: 90)
      rsi = double('rsi', ready?: true, value: 65)
      
      signal = strategy.on_candle(candle_struct.new(Time.now, 100, 90, 95), indicators: { ema_fast: ema_fast, ema_slow: ema_slow, rsi: rsi })
      expect(signal).to eq(:buy)
    end
  end

  describe Strategies::OrbStrategy do
    it 'sets range and signals breakout' do
      strategy = described_class.new(range_minutes: 10) # 2 candles
      
      t1 = Time.parse('2024-01-01T09:15:00+05:30')
      t2 = Time.parse('2024-01-01T09:20:00+05:30')
      t3 = Time.parse('2024-01-01T09:25:00+05:30')

      # Candle 1
      expect(strategy.on_candle(candle_struct.new(t1, 100, 90, 95), indicators: {})).to eq(:hold)
      # Candle 2
      expect(strategy.on_candle(candle_struct.new(t2, 105, 85, 100), indicators: {})).to eq(:hold)
      # Candle 3 (Breakout above 105)
      expect(strategy.on_candle(candle_struct.new(t3, 110, 100, 108), indicators: {})).to eq(:buy)
    end
  end

  describe Strategies::VixSpikeStrategy do
    it 'signals buy when VIX > threshold' do
      strategy = described_class.new(vix_threshold: 15)
      
      vix = double('vix', ready?: true, value: 16)
      signal = strategy.on_candle(candle_struct.new(Time.now, 100, 90, 95), indicators: { vix: vix })
      expect(signal).to eq(:buy)
      
      vix = double('vix', ready?: true, value: 14)
      signal = strategy.on_candle(candle_struct.new(Time.now, 100, 90, 95), indicators: { vix: vix })
      expect(signal).to eq(:hold)
    end
  end
end
