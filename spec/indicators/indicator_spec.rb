# frozen_string_literal: true

require 'spec_helper'
require_relative '../../src/indicators/ema'
require_relative '../../src/indicators/rsi'
require_relative '../../src/indicators/atr'
require_relative '../../src/indicators/vix_reader'
require_relative '../../src/market_data/candle'

RSpec.describe Indicators do
  let(:candle_struct) { Struct.new(:high, :low, :close) }

  describe Indicators::Ema do
    it 'calculates EMA correctly' do
      ema = described_class.new(period: 3)
      prices = [10, 11, 12, 13, 14]
      
      prices.each { |p| ema.update(candle_struct.new(p, p, p)) }
      
      expect(ema.ready?).to be true
      expect(ema.value).to eq(13.0)
    end
  end

  describe Indicators::Rsi do
    it 'calculates RSI correctly' do
      rsi = described_class.new(period: 2)
      prices = [10, 12, 11, 13, 15] 
      
      prices.each { |p| rsi.update(candle_struct.new(p, p, p)) }
      
      expect(rsi.ready?).to be true
      expect(rsi.value).to be > 0.0
      expect(rsi.value).to be < 100.0
    end
  end

  describe Indicators::Atr do
    it 'calculates ATR correctly' do
      atr = described_class.new(period: 2)
      atr.update(candle_struct.new(12, 10, 11))
      atr.update(candle_struct.new(14, 10, 13))
      
      expect(atr.ready?).to be true
      expect(atr.value).to eq(3.0)
      
      atr.update(candle_struct.new(15, 12, 14))
      expect(atr.value).to eq(3.0)
    end
  end

  describe Indicators::VixReader do
    it 'updates value correctly' do
      vix = described_class.new
      expect(vix.ready?).to be false
      vix.update(candle_struct.new(15.5, 14.5, 15.0))
      expect(vix.ready?).to be true
      expect(vix.value).to eq(15.0)
    end
  end
end
