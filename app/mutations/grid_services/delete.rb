module GridServices
  class Delete < Mutations::Command
    required do
      model :current_user, class: User
      model :grid_service
    end

    def execute
      prev_state = self.grid_service.state
      begin
        self.grid_service.set_state('deleting')
        self.grid_service.containers.each do |container|
          Docker::ContainerRemover.new(container).remove_container
        end
        self.grid_service.containers.volumes.each do |container|
          Docker::ContainerRemover.new(container).remove_container
        end
      rescue => exc
        self.grid_service.set_state(prev_state)
        raise exc
      end
      self.grid_service.destroy
    end
  end
end
