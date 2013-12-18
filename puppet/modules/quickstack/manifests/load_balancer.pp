class quickstack::load_balancer (
  $controller_priv_floating_ip,
  $controller_pub_floating_ip,
  $lb_member_names,
  $lb_member_addrs,
  $neutron         = $quickstack::params::neutron,
  $heat_cfn        = $quickstack::params::heat_cfn,
  $heat_cloudwatch = $quickstack::params::heat_cloudwatch,
) inherits quickstack::params {

  class { 'haproxy':
    global_options => {
      'log'     => '/dev/log local0',
      'pidfile' => '/var/run/haproxy.pid',
      'user'    => 'haproxy',
      'group'   => 'haproxy',
      'daemon'  => '',
      'maxconn' => '4000',
    },
    defaults_options => {
      'mode'    => 'http',
      'log'     => 'global',
      'retries' => '3',
      'option'  => [ 'httplog', 'redispatch' ],
      'timeout' => [ 'connect 10s', 'client 1m', 'server 1m' ],
    },
  }

  haproxy::listen { 'stats':
    ipaddress => '*',
    ports     => '81',
    mode      => 'http',
    options   => {
      'stats' => 'enable',
    },
    collect_exported => false,
  }

  quickstack::load_balancer::proxy { 'horizon':
    addr => [ $controller_pub_floating_ip, $controller_priv_floating_ip ],
    port => '80',
    mode => 'http',
    listen_options => {
      'option' => [ 'httplog' ],
      'cookie' => 'SERVERID insert indirect nocache',
    },
    member_options => [ 'check' ],
    define_cookies => true,
  }
  quickstack::load_balancer::proxy { 'keystone-public':
    addr => [ $controller_pub_floating_ip, $controller_priv_floating_ip ],
    port => '5000',
    mode => 'http',
    listen_options => { 'option' => [ 'httplog' ] },
    member_options => [ 'check' ],
  }
  quickstack::load_balancer::proxy { 'keystone-admin':
    addr => [ $controller_pub_floating_ip, $controller_priv_floating_ip ],
    port => '35357',
    mode => 'http',
    listen_options => { 'option' => [ 'httplog' ] },
    member_options => [ 'check' ],
  }
  if str2bool($heat_cfn) == true {
    quickstack::load_balancer::proxy { 'heat-cfn':
      addr => [ $controller_pub_floating_ip, $controller_priv_floating_ip ],
      port => '8000',
      mode => 'http',
      listen_options => { 'option' => [ 'httplog' ] },
      member_options => [ 'check' ],
    }
  }
  if str2bool($heat_cloudwatch) == true {
    quickstack::load_balancer::proxy { 'heat-cloudwatch':
      addr => [ $controller_pub_floating_ip, $controller_priv_floating_ip ],
      port => '8003',
      mode => 'http',
      listen_options => { 'option' => [ 'httplog' ] },
      member_options => [ 'check' ],
    }
  }
  quickstack::load_balancer::proxy { 'heat-api':
    addr => [ $controller_pub_floating_ip, $controller_priv_floating_ip ],
    port => '8004',
    mode => 'http',
    listen_options => { 'option' => [ 'httplog' ] },
    member_options => [ 'check' ],
  }
  quickstack::load_balancer::proxy { 'swift-proxy':
    addr => [ $controller_pub_floating_ip, $controller_priv_floating_ip ],
    port => '8080',
    mode => 'http',
    listen_options => { 'option' => [ 'httplog' ] },
    member_options => [ 'check' ],
  }
  quickstack::load_balancer::proxy { 'nova-ec2':
    addr => [ $controller_pub_floating_ip, $controller_priv_floating_ip ],
    port => '8773',
    mode => 'http',
    listen_options => { 'option' => [ 'httplog' ] },
    member_options => [ 'check' ],
  }
  quickstack::load_balancer::proxy { 'nova-compute':
    addr => [ $controller_pub_floating_ip, $controller_priv_floating_ip ],
    port => '8774',
    mode => 'http',
    listen_options => { 'option' => [ 'httplog' ] },
    member_options => [ 'check' ],
  }
  quickstack::load_balancer::proxy { 'nova-metadata':
    addr => [ $controller_pub_floating_ip, $controller_priv_floating_ip ],
    port => '8775',
    mode => 'http',
    listen_options => { 'option' => [ 'httplog' ] },
    member_options => [ 'check' ],
  }
  quickstack::load_balancer::proxy { 'cinder-api':
    addr => [ $controller_pub_floating_ip, $controller_priv_floating_ip ],
    port => '8776',
    mode => 'http',
    listen_options => { 'option' => [ 'httplog' ] },
    member_options => [ 'check' ],
  }
  quickstack::load_balancer::proxy { 'ceilometer-api':
    addr => [ $controller_pub_floating_ip, $controller_priv_floating_ip ],
    port => '8777',
    mode => 'http',
    listen_options => { 'option' => [ 'httplog' ] },
    member_options => [ 'check' ],
  }
  quickstack::load_balancer::proxy { 'glance-registry':
    addr => [ $controller_pub_floating_ip, $controller_priv_floating_ip ],
    port => '9191',
    mode => 'http',
    listen_options => { 'option' => [ 'httplog' ] },
    member_options => [ 'check' ],
  }
  quickstack::load_balancer::proxy { 'glance-api':
    addr => [ $controller_pub_floating_ip, $controller_priv_floating_ip ],
    port => '9292',
    mode => 'http',
    listen_options => { 'option' => [ 'httplog' ] },
    member_options => [ 'check' ],
  }
  if str2bool($neutron) == true {
    quickstack::load_balancer::proxy { 'neutron-api':
      addr => [ $controller_pub_floating_ip, $controller_priv_floating_ip ],
      port => '9696',
      mode => 'http',
      listen_options => { 'option' => [ 'httplog' ] },
      member_options => [ 'check' ],
    }
  }

  sysctl::value { 'net.ipv4.ip_nonlocal_bind': value => '1' }
}

define quickstack::load_balancer::proxy (
  $addr,
  $port,
  $mode,
  $listen_options,
  $member_options,
  $define_cookies = false,
) {
  include quickstack::load_balancer

  haproxy::listen { $name:
    ipaddress => $addr,
    ports     => $port,
    mode      => $mode,
    options   => $listen_options,
    collect_exported => false,
  }

  haproxy::balancermember { $name:
    listening_service => $name,
    ports             => $port,
    server_names      => split($quickstack::load_balancer::lb_member_names, ','),
    ipaddresses       => split($quickstack::load_balancer::lb_member_addrs, ','),
    options           => $member_options,
    define_cookies    => $define_cookies,
  }
}
