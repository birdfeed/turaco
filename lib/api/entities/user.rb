# frozen_string_literal: true
module API
  module Entities
    class User < Base
      property :email
      property :name
      property :id

      collection :tags { property :name }
    end
  end
end
