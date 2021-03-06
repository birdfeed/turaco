require 'rails_helper'

describe 'Organization CRUD', type: :request do 
  let(:token) { FactoryGirl.create(:researcher_token) }
  let(:results) { JSON.parse(response.body) }

  context 'PUT /organizations' do
    before do
      put '/v3/organizations',
        params: { name: 'Foo Organization' },
        headers: { 'Authorization' => "Bearer #{token.token}" }
    end

    it 'should create the organization' do
      expect(response.code).to eql('201')
      expect(Organization.find(results['id'])).to be_present
    end
  end

  context 'GET /organizations' do
    let!(:organizations) do
      FactoryGirl.create_list(
        :organization, 15, users: [User.find(token.resource_owner_id)]
      ) 
    end

    let!(:not_in_orgs) { FactoryGirl.create_list(:organization, 5) }

    before do
      get '/v3/organizations', 
        headers: { 'Authorization' => "Bearer #{token.token}" }
    end

    it 'should find organizations that I am a member of' do 
      expect(response.code).to eql('200')
      ids = results['organizations'].map { |x| x['id'] }
      expect(ids).to match_array(organizations.pluck(:id))
      expect(ids).to_not match_array(not_in_orgs.pluck(:id))
    end

    context 'by ID' do
      before do
        get "/v3/organizations/#{organizations.first.id}", 
          headers: { 'Authorization' => "Bearer #{token.token}" }
      end

      it 'should find the organization' do
        expect(response.code).to eql('200')
        expect(results['id']).to eql(organizations.first.id) 
      end
    end

    context 'tags / with elasticsearch' do
      before do
        allow_any_instance_of(Kagu::Query::Elastic).to receive(:search)
          .with('tags' => tags)
          .and_return(::Organization.joins(:tags).where(
              tags: { name: tags.split }
          ))

        organizations.last(5).each do |s|
          s.tags << 'foo'
        end

        get '/v3/organizations',
          params: { tags: tags }, headers: { 
            'Authorization' => "Bearer #{token.token}" 
          }
      end

      let(:tags) { 'foo bar' }

      it 'calls the adapter' do
        expect(response.code).to eql('200')
        expect(results['organizations'].count).to eql(5)
      end
    end
  end

  context 'POST /organizations' do
    let(:org) do
      FactoryGirl.create(:organization, users: [User.find(token.resource_owner_id)])
    end

    let(:samples) do
      FactoryGirl.create_list(:sample, 5, user_id: token.resource_owner_id)
    end

    let(:experiments) do
      FactoryGirl.create_list(:experiment, 5, user_id: token.resource_owner_id)
    end

    let(:new_name) { 'foobar' }

    before do
      post "/v3/organizations/#{org.id}",
        params: { 
          name: new_name,
          sample_ids: samples.map(&:id),
          experiment_ids: experiments.map(&:id)
        },
        headers: { 'Authorization' => "Bearer #{token.token}" }
    end

    it 'should update the organization' do
      expect(response.code).to eql('200')
      org.reload
      expect(org.name).to eql(new_name)
      expect(org.samples).to include(*samples)
      expect(org.experiments).to include(*experiments)
    end
  end

  context 'POST /organizations/:id/user' do
    let(:org) do
      FactoryGirl.create(:organization, users: [User.find(token.resource_owner_id)])
    end

    let(:user) do
      FactoryGirl.create(:user)
    end

    before do
      post "/v3/organizations/#{org.id}/user",
        params: {email: user.email},
        headers: { 'Authorization' => "Bearer #{token.token}" }
    end

    it 'should add the user to the organization' do
      expect(response.code).to eql('204')
      org.reload
      expect(org.users).to include(user)
    end
  end

  context 'GET /organizations/:id/users' do
    let(:users) do
      FactoryGirl.create_list(:user, 5).push(
        User.find(token.resource_owner_id)
      )
    end

    let(:org) do
      FactoryGirl.create(:organization, users: users)
    end

    before do
      get "/v3/organizations/#{org.id}/users",
        headers: { 'Authorization' => "Bearer #{token.token}" }
    end

    it 'should get the users of an organization' do
      expect(response.code).to eql('200')
      expect(results["users"].map { |x| x['id'] }).to include(*users.pluck(:id))
    end
  end

  context 'GET /organizations/:id/samples' do
    let(:samples) { FactoryGirl.create_list(:sample, 15) }
    let(:org) { FactoryGirl.create(:organization, samples: samples) }

    before do
      org.users << User.find(token.resource_owner_id)

      get "/v3/organizations/#{org.id}/samples",
        headers: { 'Authorization' => "Bearer #{token.token}" }
    end

    it 'should return the correct samples' do
      expect(response.code).to eql('200')
      expect(results['samples'].map { |s| s['id'] })
        .to include(*samples.pluck(:id))
    end
  end

  context 'GET /organizations/:id/experiments' do
    let(:experiments) { FactoryGirl.create_list(:experiment, 15) }
    let(:org) { FactoryGirl.create(:organization, experiments: experiments) }

    before do
      org.users << User.find(token.resource_owner_id)

      get "/v3/organizations/#{org.id}/experiments",
        headers: { 'Authorization' => "Bearer #{token.token}" }
    end

    it 'should return the correct experiments' do
      expect(response.code).to eql('200')
      expect(results['experiments'].map { |s| s['id'] })
        .to include(*experiments.pluck(:id))
    end
  end
end