require 'rails_helper'

describe 'Sample CRUD', type: :request do 
  let(:user) { FactoryGirl.create(:user) }
  let(:attachment) { Rack::Test::UploadedFile.new(
    "./spec/support/sample.wav", "audio/wav") }
  
  context 'PUT /sample' do 
    before do
      allow(Adapters::S3).to receive(:upload_file).and_return(true)

      put '/v3/sample', 
        user_id: user.id,
        name: 'name',
        private: false,
        file: attachment,
        low_label: 'not R',
        high_label: 'R'
    end

    let(:result) { JSON.parse(response.body) }

    it 'should create a sample' do 
      expect(Adapters::S3)
        .to have_received(:upload_file)
        .with(
          'birdfeedtemp', instance_of(String),attachment.original_filename
        )

      expect(response.code).to eql('201')
    end

    context 'with invalid/missing parameters' do 
      before { put '/v3/sample', user_id: user.id }

      it 'should enforce required' do 
        expect(response.code).to eql('400')
        expect(JSON.parse(response.body)).to have_key('error')
      end
    end
  end

  context 'GET /sample' do
    let(:samples) { FactoryGirl.create_list(:sample, 15) }

    context 'get single sample' do
      before do
        get "/v3/sample/#{samples.first.id}"
      end

      let(:result) { JSON.parse(response.body) }

      it 'should retrieve an existing sample' do
        expect(response.code).to eql('200')
      end
    end

    context 'get all samples' do
      before do
        get '/v3/sample/'
      end

      let(:result) { JSON.parse(response.body) }

      it 'should get all samples' do
        binding.pry
        expect(response.code).to eql('200')
      end
    end
  end
end