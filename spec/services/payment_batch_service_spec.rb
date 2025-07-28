require 'logger'
require_relative '../spec_helper'
require_relative '../../services/payment_batch_service'

require_relative '../../services/validators/base_validator'
require_relative '../../services/validators/default_validator'
require_relative '../../services/validators/company_with_reference_validator'
require_relative '../../services/validators/registry'

RSpec.describe PaymentBatchService do
  before do
    class_double("PaymentExporter").as_stubbed_const
    class_double("PaymentCreationJob").as_stubbed_const
    class_double("Company").as_stubbed_const
  end

  before do
    allow($stdout).to receive(:puts)
  end

  describe '.trigger' do
    it 'enqueues a PaymentExporter job' do
      expect(PaymentExporter).to receive(:perform_async).once
      described_class.trigger
    end
  end

  describe '.create' do
    let(:today) { Date.parse('2025-07-28') }
    let(:company_id) { 'f8b8f2d0-2e6a-4b9e-8b0c-1e1a1d1e1a1d' }
    let(:batch_id) { 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d' }
    let(:callback_url) { "https://example.com/callback" }
    let(:valid_payment) do
      {
        'employee_id'  => 'c6d7e8f9-a0b1-4c2d-8e3f-4a5b6c7d8e9f',
        'bank_bsb'     => '012345',
        'bank_account' => '111222333',
        'amount_cents' => 50000,
        'currency'     => 'AUD',
        'pay_date'     => '2025-07-29'
      }
    end
    let(:request_params) do
      {
        'company_id'   => company_id,
        'batch_id'     => batch_id,
        'callback_url' => callback_url,
        'payments'     => [valid_payment]
      }
    end

    before do
      allow(Date).to receive(:today).and_return(today)
      allow(Company).to receive(:exists?).and_return(true)
    end

    context 'when params are valid' do
      it 'enqueues a job and returns an accepted response' do
        expect(PaymentCreationJob).to receive(:perform_async)

        response = described_class.create(request_params)

        expect(response[:success]).to be true
        expect(response[:status]).to eq(201)
        expect(response[:message]).to include("1 payments has been enqueued")
      end
    end

    context 'when validation fails' do
      it 'does not enqueue a PaymentCreationJob' do
        expect(PaymentCreationJob).not_to receive(:perform_async)
        invalid_params = request_params.except('company_id')
        described_class.create(invalid_params)
      end

      context 'because company does not exist' do
        it 'returns a failure response' do
          allow(Company).to receive(:exists?).with(id: company_id, active: true).and_return(false)
          response = described_class.create(request_params)
          expect(response[:success]).to be false
          expect(response[:errors]).to include("Company with id=#{company_id} was not found or is not active.")
        end
      end

      context 'because batch_id is missing' do
        it 'returns a failure response' do
          request_params.delete('batch_id')
          response = described_class.create(request_params)
          expect(response[:success]).to be false
          expect(response[:errors]).to include('Request must include a batch_id.')
        end
      end

      context 'because bsb format is incorrect' do
        it 'returns a failure response' do
          request_params['payments'].first['bank_bsb'] = '123-456'
          response = described_class.create(request_params)
          expect(response[:success]).to be false
          expect(response[:errors]).to include("Payment #1: bank_bsb must be exactly 6 digits.")
        end
      end

      context 'because bank account format is incorrect' do
        it 'returns a failure response' do
          request_params['payments'].first['bank_account'] = '123'
          response = described_class.create(request_params)
          expect(response[:success]).to be false
          expect(response[:errors]).to include("Payment #1: bank_account must be between 6 and 9 digits.")
        end
      end

      context 'because pay_date is in the past' do
        it 'returns a failure response' do
          request_params['payments'].first['pay_date'] = '2025-07-27'
          response = described_class.create(request_params)
          expect(response[:success]).to be false
          expect(response[:errors]).to include("Payment #1: pay_date cannot be in the past.")
        end
      end

      context 'because amount_cents is zero' do
        it 'returns a failure response' do
          request_params['payments'].first['amount_cents'] = 0
          response = described_class.create(request_params)
          expect(response[:success]).to be false
          expect(response[:errors]).to include("Payment #1: amount_cents must be an integer greater than 0.")
        end
      end
    end
  end
end