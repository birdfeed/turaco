# frozen_string_literal: true
module API
  module Endpoints
    class Organization < Grape::API
      extend API::Meta::RelationCollections
      extend API::Meta::SimpleReads

      resource :organizations
      authorize_routes!

      desc 'Create an organization'
      route_setting :scopes, %w(administrator researcher)
      params do
        requires :name, type: String, desc: 'Name of organization',
                        documentation: { param_type: 'body' }
      end
      put do
        status 201

        new_org = ::Organization.create(declared_hash)
        new_org.users << current_user
        new_org.save

        Kagu::Events::PostgresProducer.call(new_org)
        present(new_org, with: Entities::Organization)
      end

      desc 'List organizations'
      route_setting :scopes, %w(administrator researcher participant)
      params do
        optional :name, type: String, desc: 'Name of the organization'
        optional :tags, type: String, desc: 'Whitespace delimited string of '\
          'tags.'
      end
      get authorize: [:read, ::Organization] do
        status 200

        organizations = Kagu::Query::Elastic.for(::Organization).search(
          declared_hash.extract!('tags', 'name')
        ).where(declared_hash).accessible_by(current_ability)

        present(organizations, with: Entities::Collection)
      end

      desc 'Update an organization'
      route_setting :scopes, %w(administrator researcher)
      params do
        requires :id, type: Integer, desc: 'ID of organization'
        optional :name, type: String, desc: 'Name of organization',
                        documentation: { param_type: 'body' }
        optional :sample_ids, type: Array, desc: 'IDs of samples'
        optional :experiment_ids, type: Array, desc: 'IDs of experiments'
      end
      post '/:id', authorize: [:write, ::Organization] do
        status 200

        org = ::Organization.accessible_by(current_ability)
                            .find(declared_params[:id])

        org.update_attributes(
          declared_hash.except(:experiment_ids, :sample_ids)
        )

        # Update experiments if a list was provided
        if declared_params.key?(:experiment_ids)
          org.experiments =
            ::Experiment.accessible_by(current_ability).find(
              declared_params[:experiment_ids]
            )
        end

        # Update samples if a list was provided
        if declared_params.key?(:sample_ids)
          org.samples =
            ::Sample.accessible_by(current_ability).find(
              declared_params[:sample_ids]
            )
        end

        org.save

        Kagu::Events::PostgresProducer.call(org)
        present(org, with: Entities::Organization)
      end

      desc 'Add a user to an organization'
      route_setting :scopes, %w(administrator researcher)
      params do
        requires :id, type: Integer, desc: 'ID of organization'
        requires :email, type: String, desc: 'Email of user'
      end
      post '/:id/user', authorize: [:write, ::Organization] do
        status 204

        org = ::Organization.accessible_by(current_ability)
                            .find(declared_params[:id])
        user = ::User.find_by(email: declared_params[:email])

        org.users << user
        nil
      end

      get_by_id scopes: %w(administrator researcher participant),
                authorize: [:read, ::Organization]

      get_for relation: :users,
              scopes: %w(administrator researcher),
              authorize: [:read, ::Organization]

      get_for relation: :samples,
              scopes: %w(administrator researcher),
              authorize: [:read, ::Organization]

      get_for relation: :experiments,
              scopes: %w(administrator researcher),
              authorize: [:read, ::Organization]
    end
  end
end
