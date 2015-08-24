require_relative 'common'

module Kontena::Cli::Grids
  class CurrentCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    def execute
      require_api_url
      if current_grid.nil?
        abort 'No grid selected. To select grid, please run: kontena grid use <grid name>'
      else
        grid = client(require_token).get("grids/#{current_grid}")
        print_grid(grid)
      end
    end
  end
end
