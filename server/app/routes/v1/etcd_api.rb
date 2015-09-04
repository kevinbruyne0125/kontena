module V1
  class EtcdApi < Roda
    include OAuth2TokenVerifier
    include CurrentUser
    include RequestHelpers

    route do |r|

      validate_access_token
      require_current_user

      def load_grid(grid_name)
        grid = Grid.find_by(name: grid_name)
        halt_request(404, {error: 'Not found'}) if !grid

        unless current_user.grid_ids.include?(grid.id)
          halt_request(403, {error: 'Access denied'})
        end

        grid
      end

      # /v1/etcd/:grid_name/:path
      r.on /([^\/]+)\/(.+)/ do |grid_name, path|
        grid = load_grid(grid_name)
        node = grid.host_nodes.connected.first
        halt_request(404, {error: 'Not connected to any nodes'}) if !node

        client = node.rpc_client(2)

        r.get do
          r.is do
            response = client.request("/etcd/get", path)
            p response
          end
        end

        r.post do
          r.is do
            data = parse_json_body
            client.request("/etcd/set", path, {value: data['value']})
          end
        end

        r.delete do
          r.is do
            data = parse_json_body
            params = {}
            params[:recursive] = data['recursive'] || false
            client.request("/etcd/delete", path, params)
          end
        end
      end
    end
  end
end
