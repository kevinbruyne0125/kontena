require 'yaml'
require_relative 'common'

module Kontena::Cli::Apps
  class DeployCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['--no-build'], :flag, 'Don\'t build an image, even if it\'s missing', default: false
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'

    parameter "[SERVICE] ...", "Services to start"

    attr_reader :services, :service_prefix

    def execute
      require_api_url
      require_token
      @services = load_services_from_yml
      Dir.chdir(File.dirname(filename))
      build_services(services) unless no_build?
      init_services(services)
      deploy_services(deploy_queue)
    end

    private

    def build_services(services)
      return unless dockerfile

      services.each do |name, service|
        if service['build'] && build_needed?(service['image'])
          puts "Building image #{service['image'].colorize(:cyan)}"
          build_docker_image(service['image'], service['build'])
          puts "Pushing image #{service['image'].colorize(:cyan)} to registry"
          push_docker_image(service['image'])
        end
      end
    end

    def dockerfile
      @dockerfile ||= File.new('Dockerfile') rescue nil
    end

    def init_services(services)
      services.each do |name, config|
        create_or_update_service(name, config)
      end
    end

    def deploy_services(queue)
      queue.each do |service|
        puts "deploying #{service['id'].colorize(:cyan)}"
        data = {}
        if service['deploy']
          data[:strategy] = service['deploy']['strategy'] if service['deploy']['strategy']
          data[:wait_for_port] = service['deploy']['wait_for_port'] if service['deploy']['wait_for_port']
        end
        deploy_service(token, service['id'].split('/').last, data)
      end
    end

    def build_docker_image(name, path)
      system("docker build -t #{name} #{path}")
    end

    def push_docker_image(image)
      system("docker push #{image}")
    end

    def create_or_update_service(name, options)

      # skip if service is already created or updated or it's not present
      return nil if in_deploy_queue?(name) || !services.keys.include?(name)

      # create/update linked services recursively before continuing
      unless options['links'].nil?
        parse_links(options['links']).each_with_index do |linked_service, index|
          # change prefixed service name also to links options
          options['links'][index] = "#{prefixed_name(linked_service[:name])}:#{linked_service[:alias]}"

          create_or_update_service(linked_service[:name], services[linked_service[:name]]) unless in_deploy_queue?(linked_service[:name])
        end
      end

      merge_env_vars(options)

      if service_exists?(name)
        service = update(name, options)
      else
        service = create(name, options)
      end

      # add deploy options to service
      service['deploy'] = options['deploy']

      deploy_queue.push service
    end

    def find_service_by_name(name)
      get_service(token, prefixed_name(name)) rescue nil
    end

    def create(name, options)
      name = prefixed_name(name)
      puts "creating #{name.colorize(:cyan)}"
      data = {name: name}
      data.merge!(parse_data(options))
      create_service(token, current_grid, data)
    end

    def update(id, options)
      id = prefixed_name(id)
      data = parse_data(options)
      puts "updating #{id.colorize(:cyan)}"
      update_service(token, id, data)
    end

    def build_needed?(image)
      docker_file_timestamp = dockerfile.mtime
      image_info = `docker inspect #{image.split(' ').first} 2>&1` ; result=$?.success?
      if result
        image_info = JSON.parse(image_info)
        docker_file_timestamp > DateTime.parse(image_info[0]['Created']).to_time
      else
        true
      end
    end


    def in_deploy_queue?(name)
      deploy_queue.find {|service| service['name'] == prefixed_name(name)} != nil
    end

    def merge_env_vars(options)
      return unless options['env_file']

      options['env_file'] = [options['env_file']] if options['env_file'].is_a?(String)
      options['environment'] = [] unless options['environment']

      options['env_file'].each do |env_file|
        options['environment'].concat(read_env_file(env_file))
      end

      options['environment'].uniq! {|s| s.split('=').first}
    end

    def read_env_file(path)
      File.readlines(path).delete_if { |line| line.start_with?('#') || line.empty? }
    end

    ##
    # @param [Hash] options
    def parse_data(options)
      data = {}
      data[:image] = options['image']
      data[:env] = options['environment']
      data[:container_count] = options['instances']
      data[:links] = parse_links(options['links']) if options['links']
      data[:ports] = parse_ports(options['ports']) if options['ports']
      data[:memory] = parse_memory(options['mem_limit']) if options['mem_limit']
      data[:memory_swap] = parse_memory(options['memswap_limit']) if options['memswap_limit']
      data[:cpu_shares] = options['cpu_shares'] if options['cpu_shares']
      data[:volumes] = options['volumes'] if options['volumes']
      data[:volumes_from] = options['volumes_from'] if options['volumes_from']
      data[:cmd] = options['command'].split(" ") if options['command']
      data[:affinity] = options['affinity'] if options['affinity']
      data[:user] = options['user'] if options['user']
      data[:stateful] = options['stateful'] == true
      data[:cap_add] = options['cap_add'] if options['cap_add']
      data[:cap_drop] = options['cap_drop'] if options['cap_drop']
      data
    end

    def deploy_queue
      @deploy_queue ||= []
    end
  end
end
