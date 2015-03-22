require './app/helpers/random_name_helper'

module Grids
  class Create < Mutations::Command
    include RandomNameHelper

    required do
      model :user
      string :name, nils: true, min_length: 3
    end

    def execute
      self.name = generate_name if self.name.blank?
      grid = Grid.create(name: self.name)
      if grid.errors.size > 0
        grid.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end
      user.grids << grid

      grid
    end

  end
end
