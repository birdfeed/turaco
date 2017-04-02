require 'rails_helper'

describe 'Experiment CRUD', type: :request do 
  
  let!(:user) { FactoryGirl.create(:user) }
  let(:app_token) { FactoryGirl.create(:app_token) }

  context 'PUT /experiment' do 
    before do
      put '/v3/experiment',
      params: { 
        name: 'name',
        user_id: user.id
      },
      headers: { 'Turaco-Api-Key' => app_token.token }
    end
    let(:result) { JSON.parse(response.body) }

    it 'should create an experiment' do 
      expect(response.code).to eql('201')
    end
  end

  context 'DELETE /experiment' do
    let!(:experiment) { FactoryGirl.create(:experiment) }

    context 'delete an experiment' do
      before do
        delete "/v3/experiment/#{experiment.id}",
          headers: { 'Turaco-Api-Key' => app_token.token }
      end

      let!(:result) { JSON.parse(response.body) }

      it 'should have deleted the experiment' do
        expect(response.code).to eql('204')
        expect(::Experiment.exists?(experiment.id)).to eql(false)
      end
    end
  end

  context 'UPDATE /experiment' do
    let! (:experiment) { FactoryGirl.create(:experiment) }

    context 'update an experiment' do
      before do
        put "/v3/experiment/#{experiment.id}",
        params: {
          name: 'new_name'
        },
        headers: { 'Turaco-Api-Key' => app_token.token }
      end

      let!(:result) { JSON.parse(response.body) }

      it 'should have updated the experiment' do
        expect(response.code).to eql('204')
        expect(::Experiment.find(experiment.id).name).to eql('new_name')
      end
    end
  end

  context 'GET /experiment' do 
    let!(:experiments) { FactoryGirl.create_list(:experiment, 25) }

    context 'get single experiment' do
      before do
        get "/v3/experiment/#{experiments.first.id}",
          headers: { 'Turaco-Api-Key' => app_token.token }
      end

      let!(:result) { JSON.parse(response.body) }

      it 'should retrieve an existing experiment' do
        expect(response.code).to eql('200')
      end
    end

    context 'with no filters' do
      before do 
        get '/v3/experiment',
          headers: { 'Turaco-Api-Key' => app_token.token }
      end

      let(:results) { JSON.parse(response.body) }

      it 'should return all the experiments' do
        expect(results['experiments'].count).to eql(25)
        expect(response.code).to eql('200')
      end
    end

    context 'with querystring filters' do 
      before do
        experiments.last.name = 'foobar'
        experiments.last.save

        get '/v3/experiment', params: { name: 'foobar' }, headers: { 
          'Turaco-Api-Key' => app_token.token 
        }
      end

      let(:results) { JSON.parse(response.body) }

      it 'should return the correct experiments' do 
        expect(response.code).to eql('200')
        expect(results['experiments'].first['links'].first['href'])
        .to eql("http://www.example.com/v3/experiment/#{experiments.last.id}")
      end
    end
  end
end
