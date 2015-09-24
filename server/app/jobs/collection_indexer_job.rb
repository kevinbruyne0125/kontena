
class CollectionIndexerJob
  include Celluloid
  include Celluloid::Logger

  def perform
    info 'CollectionIndexerJob: removing undefined indexes'
    Mongoid::Tasks::Database.remove_undefined_indexes
    info 'CollectionIndexerJob: removing undefined indexes finished'

    info 'CollectionIndexerJob: creating indexes'
    Mongoid::Tasks::Database.create_indexes
    info 'CollectionIndexerJob: creating indexes finished'

    migrate_overlay_cidr

    unless ContainerLog.collection.capped?
      info 'CollectionIndexerJob: converting container_logs to capped'
      ContainerLog.collection.session.command(
        convertToCapped: ContainerLog.collection.name,
        capped: true,
        size: 5.gigabytes
      )
      info 'CollectionIndexerJob: finished converting container_logs to capped'
    end

    unless ContainerStat.collection.capped?
      info 'CollectionIndexerJob: converting container_stats to capped'
      ContainerStat.collection.session.command(
        convertToCapped: ContainerStat.collection.name,
        capped: true,
        size: 1.gigabyte
      )
      info 'CollectionIndexerJob: finished converting container_stats to capped'
    end
  end

  def migrate_overlay_cidr
    Container.unscoped.where(overlay_cidr: {"$exists" => 1}).each do |c|
      data = c.raw_attributes
      if data['overlay_cidr'].include?('/')
        ip, subnet = data['overlay_cidr'].split('/')
        OverlayCidr.create(
          grid: c.grid,
          container: c,
          ip: ip,
          subnet: subnet
        )
      end
      c.unset(:overlay_cidr)
    end
  end
end
