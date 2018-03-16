require 'spec_helper'

RSpec.describe UniversalRecommender::Query do
  let(:engine) { instance_double(UniversalRecommender::Engine) }
  let(:query) { described_class.new(engine: engine) }

  describe '#for_user' do
    it 'sets the value of user for the query' do
      expect {
        query.for_user('u-1')
      }.to change {
        query.query_hash[:user]
      }.from(nil).to('u-1')
    end

    it 'returns itself' do
      expect(query.for_user('u-1')).to eq(query)
    end
  end

  describe '#limit' do
    it 'sets the value of num for the query' do
      expect {
        query.limit(20)
      }.to change {
        query.query_hash[:num]
      }.from(nil).to(20)
    end

    it 'returns itself' do
      expect(query.limit(20)).to eq(query)
    end
  end

  describe '#similar_to' do
    it 'sets the value of item for the query' do
      expect {
        query.similar_to('i-1')
      }.to change {
        query.query_hash[:item]
      }.from(nil).to('i-1')
    end

    it 'returns itself' do
      expect(query.similar_to('i-1')).to eq(query)
    end
  end

  describe '#where' do
    it 'adds a filter' do
      expect {
        query.where(foo: 'bar')
      }.to change {
        Array(query.query_hash[:fields])
      }.from([]).to([{name: 'foo', values: ['bar'], bias: -1.0}])
    end

    it 'returns itself' do
      expect(query.where).to eq(query)
    end
  end

  describe '#not' do
    it 'adds an exclusion' do
      expect {
        query.not(foo: 'bar')
      }.to change {
        Array(query.query_hash[:fields])
      }.from([]).to([{name: 'foo', values: ['bar'], bias: 0.0}])
    end

    it 'returns itself' do
      expect(query.not).to eq(query)
    end
  end

  describe '#deboost' do
    it 'adds a boost' do
      expect {
        query.deboost(amount: 0.75, foo: 'bar')
      }.to change {
        Array(query.query_hash[:fields])
      }.from([]).to([{name: 'foo', values: ['bar'], bias: 0.75}])
    end

    it 'returns itself' do
      expect(query.deboost(amount: 0.75)).to eq(query)
    end

    context 'when given an amount less than or equal to 0.0' do
      it 'raises an ArgumentError' do
        aggregate_failures do
          expect { query.deboost(amount: 0.0) }.to raise_error(ArgumentError)
          expect { query.deboost(amount: -0.1) }.to raise_error(ArgumentError)
        end
      end
    end

    context 'when given an amount greater than or equal 1.0' do
      it 'raises an ArgumentError' do
        aggregate_failures do
          expect { query.deboost(amount: 1.0) }.to raise_error(ArgumentError)
          expect { query.deboost(amount: 1.1) }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe '#boost' do
    it 'adds a boost' do
      expect {
        query.boost(amount: 1.05, foo: 'bar')
      }.to change {
        Array(query.query_hash[:fields])
      }.from([]).to([{name: 'foo', values: ['bar'], bias: 1.05}])
    end

    it 'returns itself' do
      expect(query.boost(amount: 1.05)).to eq(query)
    end

    context 'when given an amount less than or equal to 1.0' do
      it 'raises an ArgumentError' do
        aggregate_failures do
          expect { query.boost(amount: 1.0) }.to raise_error(ArgumentError)
          expect { query.boost(amount: 0.9) }.to raise_error(ArgumentError)
        end
      end
    end
  end

  describe '#to_a' do
    it 'returns results' do
      allow(engine).to receive(:execute_query).and_return(['i-1'])
      expect(query.to_a).to eq(['i-1'])
    end
  end
end
