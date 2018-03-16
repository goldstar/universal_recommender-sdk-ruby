require 'spec_helper'

RSpec.describe UniversalRecommender::Engine do
  let(:engine_client) { instance_double(PredictionIO::EngineClient) }
  let(:event_client) { instance_double(PredictionIO::EventClient) }
  let(:engine) {
    described_class.new(
      host: 'example.com',
      engine_port: 8000,
      event_port: 7070,
      access_key: 'abc123',
      threads: 1
    )
  }

  describe '#engine_client' do
    it 'properly builds and returns a PredictionIO::EngineClient' do
      aggregate_failures do
        expect(PredictionIO::EngineClient).to receive(:new).once
          .with('http://example.com:8000').and_call_original
        expect(engine.engine_client).to be_a(PredictionIO::EngineClient)
      end
    end
  end

  describe '#event_client' do
    it 'properly builds and returns a PredictionIO::EventClient' do
      aggregate_failures do
        expect(PredictionIO::EventClient).to receive(:new).once.with('abc123',
          'http://example.com:7070', 1).and_call_original
        expect(engine.event_client).to be_a(PredictionIO::EventClient)
      end
    end
  end

  describe '#execute_query' do
    let(:query) { UniversalRecommender::Query.new }
    before do
      allow(engine).to receive(:engine_client).and_return(engine_client)
    end

    context 'when query returns no results' do
      let(:results) { {'itemScores' => []} }
      before { allow(engine_client).to receive(:send_query).and_return(results) }

      it 'returns an empty array' do
        expect(engine.execute_query(query)).to eq([])
      end
    end

    context 'when query returns results' do
      let(:results) { {'itemScores' => [{'item' => 'i-1', 'score' => 0.0}]} }
      before do
        allow(engine_client).to receive(:send_query).and_return(results)
        engine.define_singleton_method(:reifier) {|query_results, _|
          query_results.map {|item_score| item_score['item'] }
        }
      end

      context 'when reify is false' do
        it 'returns an array of item score hashes' do
          expect(engine.execute_query(query, reify: false))
            .to eq([{'item' => 'i-1', 'score' => 0.0}])
        end
      end

      context 'when reify is true' do
        it 'returns reified results' do
          expect(engine.execute_query(query, reify: true)).to eq(['i-1'])
        end
      end

      it 'reifies results by default' do
        expect(engine.execute_query(query)).to eq(['i-1'])
      end
    end
  end

  describe '#reify' do
    let(:query_results) { [{'item' => 'i-1', 'score' => 0.0}] }

    context 'when the engine has a reifier' do
      before do
        engine.define_singleton_method(:reifier) {|query_results, _|
          query_results.map {|item_score| item_score['item'] }
        }
      end

      it 'returns the reified query results' do
        expect(engine.reify(query_results)).to eq(['i-1'])
      end
    end

    context 'when the engine does not have a reifier' do
      it 'returns the original query results' do
        expect(engine.reify(query_results))
      end
    end
  end

  describe '#upsert_entity' do
    before do
      allow(engine).to receive(:event_client).and_return(event_client)
    end

    it 'sends a $set event to the event_client' do
      expect(engine.event_client).to receive(:create_event).once
        .with('$set', 'item', 'i-1', {properties: {foo: ['bar']}})
      engine.upsert_entity(type: 'item', id: 'i-1', properties: {foo: ['bar']})
    end
  end

  describe '#export_entity' do
    let(:io) { StringIO.new }

    it 'appends to an io object a json line' do
      expected = JSON.dump(
        event: '$set',
        entityType: 'user',
        entityId: 'u-1',
        properties: {
          foo: ['bar']
        }
      )
      expect {
        engine.export_entity(
          io: io,
          type: 'user',
          id: 'u-1',
          properties: {foo: ['bar']}
        )
      }.to change { io.rewind; io.read.chomp }.from('').to(expected)
    end
  end

  describe '#record_event' do
    let(:event_time) { 5.minutes.ago }
    before do
      allow(engine).to receive(:event_client).and_return(event_client)
    end

    it 'sends named events to the event_client' do
      expect(engine.event_client).to receive(:create_event).once
        .with('viewed-item', 'user', 'u-1', {
          targetEntityType: 'item',
          targetEntityId: 'i-1',
          properties: {foo: ['bar']},
          eventTime: event_time.to_s(:iso8601)
        })

      engine.record_event(
        type: 'viewed-item',
        user: 'u-1',
        item: 'i-1',
        at: event_time,
        properties: {foo: ['bar']}
      )
    end
  end

  describe '#export_event' do
    let(:event_time) { 5.minutes.ago }
    let(:io) { StringIO.new }

    it 'appends to an io object a json line' do
      expected = JSON.dump(
        event: 'viewed-item',
        entityType: 'user',
        entityId: 'u-1',
        targetEntityType: 'item',
        targetEntityId: 'i-1',
        properties: {
          foo: ['bar']
        },
        eventTime: event_time.to_s(:iso8601)
      )
      expect {
        engine.export_event(
          io: io,
          type: 'viewed-item',
          user: 'u-1',
          item: 'i-1',
          at: event_time,
          properties: {foo: ['bar']}
        )
      }.to change { io.rewind; io.read.chomp }.from('').to(expected)
    end
  end
end
