# frozen_string_literal: true
module API
  module Entities
    class Collection < Grape::Roar::Decorator
      include Roar::JSON
      include Roar::Hypermedia

      class << self
        def represent(object, _options = {})
          extract_from_relation(object) if object.is_a?(ActiveRecord::Relation)
          super
        end

        private

        def extract_from_relation(relation)
          str_klass = relation.klass.name.demodulize

          collection(str_klass.downcase.pluralize.to_sym,
                     extend: "API::Entities::#{str_klass}".constantize,
                     class: relation.klass)

          relation.class.send(
            :define_method,
            str_klass.downcase.pluralize,
            -> { self }
          )
        end
      end

      link :self do |opts|
        request = Grape::Request.new(opts[:env])
        "#{request.base_url}#{request.path}/#{represented.try(:id)}"
      end
    end
  end
end
