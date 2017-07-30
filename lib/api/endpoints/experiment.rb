# frozen_string_literal: true
module API
  module Endpoints
    class Experiment < Grape::API
      extend API::Meta::SimpleReads

      resource :experiments
      authorize_routes!

      desc 'Record an experiment'
      route_setting :scopes, %w(administrator researcher)
      params do
        requires :name, type: String, desc: 'Name of experiment'
        optional :active, type: Boolean, desc: 'Active flag for experiment'
        optional :organization_id, type: Integer, desc: 'Organization to '\
                 'create experiment under'
        optional :repeats, type: Integer, desc: 'Number of times all samples '\
                 'are played during an experiment'
        optional :replays, type: Integer, desc: 'Number of times a '\
                 'participant can play a sample'
        optional :tags, type: String, desc: 'Whitespace delimited tags'
      end
      put authorize: [:write, ::Experiment] do
        status 201

        experiment = ::Experiment.create(
          declared_hash.except(:tags, :organization_id)
                       .merge(user_id: current_user.id)
        )

        experiment.tags << declared_params[:tags]
                           .split(' ') if declared_params.key?(:tags)

        if declared_params.key?(:organization_id)
          experiment.organization = ::Organization
                                    .accessible_by(current_ability)
                                    .find(declared_hash[:organization_id])

          experiment.save
        end

        Kagu::Events::PostgresProducer.call(experiment)

        present(experiment, with: Entities::Experiment)
      end

      desc 'Retrieve a list of experiments'
      params do
        optional :name, type: String, desc: 'Name of the experiment'
        optional :active, type: Boolean, desc: 'Active flag for experiments'
        optional :tags, type: String, desc: 'Whitespace delimited string of '\
          'tags.'
      end
      get authorize: [:read, ::Experiment] do
        status 200

        experiments = Kagu::Query::Elastic.for(::Experiment).search(
          declared_hash.extract!('tags', 'name')
        ).where(declared_hash).accessible_by(current_ability)

        present(experiments, with: Entities::Collection)
      end

      desc 'Delete an experiment'
      route_setting :scopes, %w(administrator researcher)
      params do
        requires :id, type: Integer, desc: 'ID of experiment'
      end
      delete '/:id', authorize: [:write, ::Experiment] do
        status 204

        experiment = ::Experiment.find(declared_params[:id])
        Kagu::Events::PostgresProducer.call(experiment, :destroyed)
        experiment.destroy!

        nil
      end

      desc 'Update an experiment'
      route_setting :scopes, %w(administrator researcher)
      params do
        requires :id, type: Integer, desc: 'ID of experiment to be updated'
        optional :name, type: String, desc: 'Name of the experiment'
        optional :active, type: Boolean, desc: 'Flag for experiment being used'
        optional :repeats, type: Integer, desc: 'Times a sample will be '\
                 'repeated'
        optional :replays, type: Integer, desc: 'Times a participant can play '\
                 'a sample'
        optional :low_label, type: String, desc: 'Label for low bound'
        optional :high_label, type: String, desc: 'Label for upper bound'
        optional :organization_id, type: Integer, desc: 'Organization ID'
        optional :sample_ids, type: Array, desc: 'Samples to associate'
        optional :tags, type: String, desc: 'Whitespace delimited tags'
      end
      post '/:id', authorize: [:write, ::Experiment] do
        status 200

        experiment = ::Experiment.accessible_by(current_ability)
                                 .find(declared_params[:id])

        if declared_params.key?(:sample_ids)
          experiment.samples =
            ::Sample.accessible_by(current_ability).find(
              declared_hash.delete(:sample_ids)
            )
        end

        if declared_params.key?(:tags)
          tags = declared_hash.delete(:tags).split(' ')
          experiment.tags >> (experiment.tags.pluck(:name) - tags)
          experiment.tags << tags
        end

        # Update regular attributes
        experiment.update_attributes(declared_hash.except(:organization_id))

        # Append organization if present
        if declared_params.key?(:organization_id)
          experiment.organization =
            ::Organization.accessible_by(current_ability).find(
              declared_params[:organization_id]
            )
        end

        experiment.save
        Kagu::Events::PostgresProducer.call(experiment)

        present(experiment, with: Entities::Experiment)
      end

      get_by_id scopes: %w(administrator researcher),
                authorize: [:read, ::Experiment]
    end
  end
end
