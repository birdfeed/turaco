require 'rails_helper'

describe 'Experiment CRUD', type: :request do 
  
  let(:user) { FactoryGirl.create(:researcher_user) }
  let(:organization) { FactoryGirl.create(:organization, users: [user]) }
  let(:token) { FactoryGirl.create(:oauth_token, resource_owner_id: user.id) }

  let(:results) { JSON.parse(response.body) }

  context 'PUT /experiments' do 
    let(:tags) { 'foo bar' }
    let(:org_id) { nil }

    before do
      put '/v3/experiments',
      params: { 
        name: 'name',
        tags: tags,
        organization_id: org_id
      }.compact,
      headers: { 'Authorization' => "Bearer #{token.token}" }
    end

    it 'should create an experiment' do 
      expect(response.code).to eql('201')
      expect(Experiment.find(results['id']).tags.pluck(:name))
        .to match_array(tags.split(' '))
    end

    context 'organizations' do
      let(:org_id) { organization.id }

      it 'correctly assigns the organization' do 
        expect(response.code).to eql('201')
        expect(::Experiment.find(results['id']).organization.id)
          .to eql(organization.id)
      end

      # e.g. no membership to that organization
      context 'with an invalid organization_id' do
        let(:org_id) { FactoryGirl.create(:organization).id }

        it 'should not find the other organization' do
          expect(response.code).to eql('404')
        end
      end
    end
  end

  context 'DELETE /experiments' do
    let!(:experiment) { FactoryGirl.create(:experiment) }

    context 'delete an experiment' do
      before do
        delete "/v3/experiments/#{experiment.id}",
          headers: { 'Authorization' => "Bearer #{token.token}" }
      end

      let(:result) { JSON.parse(response.body) }

      it 'should have deleted the experiment' do
        expect(response.code).to eql('204')
        expect(::Experiment.exists?(experiment.id)).to eql(false)
      end
    end
  end

  context 'UPDATE /experiments' do
    let(:experiment) do 
      FactoryGirl.create(:experiment,
        user_id: token.resource_owner_id
      ).tap { |e| e.tags << %w(foo bar baz) }
    end

    let(:samples) do
      FactoryGirl.create_list(:sample, 5, user_id: token.resource_owner_id)
    end

    let(:new_tags) { %w(foo bar new) }

    before do
      post "/v3/experiments/#{experiment.id}",
      params: {
        name: 'new_name',
        organization_id: organization.id,
        sample_ids: samples.map(&:id),
        tags: new_tags.join(' ')
      },
      headers: { 'Authorization' => "Bearer #{token.token}" }
    end

    let(:result) { JSON.parse(response.body) }

    it 'should have updated the experiment' do
      expect(response.code).to eql('200')
      experiment.reload
      expect(experiment.name).to eql('new_name')
      expect(experiment.organization).to eql(organization)
      expect(experiment.samples).to include(*samples)
      expect(experiment.tags.pluck(:name)).to match_array(new_tags)
    end
  end

  context 'GET /experiments' do 
    let!(:experiments) do
      FactoryGirl.create_list(:experiment, 25, user_id: token.resource_owner_id)
    end

    context 'get single experiment' do
      before do
        get "/v3/experiments/#{experiments.first.id}",
          headers: { 'Authorization' => "Bearer #{token.token}" }
      end

      let(:result) { JSON.parse(response.body) }

      it 'should retrieve an existing experiment' do
        expect(response.code).to eql('200')
      end

      it 'should get the properties of the experiment' do
        expect(result['name']).to eql (experiments.first.name)
      end
    end

    context 'with no filters' do
      before do 
        get '/v3/experiments',
          headers: { 'Authorization' => "Bearer #{token.token}" }
      end

      it 'should return all the experiments' do
        expect(results['experiments'].count).to eql(25)
        expect(response.code).to eql('200')
      end
    end

    context 'tags / with elasticsearch' do
      before do
        allow_any_instance_of(Kagu::Query::Elastic).to receive(:search)
          .with('tags' => tags)
          .and_return(::Experiment.joins(:tags).where(
              tags: { name: tags.split }
          ))

        experiments.last(5).each do |s|
          s.tags << 'foo'
        end

        get '/v3/experiments',
          params: { tags: tags }, headers: { 
            'Authorization' => "Bearer #{token.token}" 
          }
      end

      let(:tags) { 'foo bar' }

      it 'calls the adapter' do
        expect(response.code).to eql('200')
        expect(results['experiments'].count).to eql(5)
      end
    end
  end
end
