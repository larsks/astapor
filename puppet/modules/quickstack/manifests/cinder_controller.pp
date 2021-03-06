class quickstack::cinder_controller(
  $cinder_backend_gluster      = $quickstack::params::cinder_backend_gluster,
  $cinder_backend_iscsi        = $quickstack::params::cinder_backend_iscsi,
  $cinder_db_password          = $quickstack::params::cinder_db_password,
  $cinder_gluster_volume       = $quickstack::params::cinder_gluster_volume,
  $cinder_gluster_servers      = $quickstack::params::cinder_gluster_servers,
  $cinder_user_password        = $quickstack::params::cinder_user_password,
  $controller_priv_host        = $quickstack::params::controller_priv_host,
  $mysql_host                  = $quickstack::params::mysql_host,
  $qpid_host                   = $quickstack::params::qpid_host,
  $verbose                     = $quickstack::params::verbose,
) inherits quickstack::params {

  cinder_config {
    'DEFAULT/glance_host': value => $controller_priv_host;
    'DEFAULT/notification_driver': value => 'cinder.openstack.common.notifier.rpc_notifier'
  }

  class {'cinder':
    rpc_backend    => 'cinder.openstack.common.rpc.impl_qpid',
    qpid_hostname  => $qpid_host,
    qpid_password  => 'guest',
    sql_connection => "mysql://cinder:${cinder_db_password}@${mysql_host}/cinder",
    verbose        => $verbose,
    require        => Class['openstack::db::mysql', 'qpid::server'],
  }

  class {'cinder::api':
    keystone_password => $cinder_user_password,
    keystone_tenant => "services",
    keystone_user => "cinder",
    keystone_auth_host => $controller_priv_host,
  }

  class {'cinder::scheduler': }

  if str2bool($cinder_backend_gluster) == true {
    class { 'cinder::volume': }

    class { 'gluster::client': }

    if ($::selinux != "false") {
      selboolean{'virt_use_fusefs':
          value => on,
          persistent => true,
      }
    }

    class { 'cinder::volume::glusterfs':
      glusterfs_mount_point_base => '/var/lib/cinder/volumes',
      glusterfs_shares           => suffix($cinder_gluster_servers, ":/${cinder_gluster_volume}")
    }
  }
}
