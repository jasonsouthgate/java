# Class: tomcat
#
# Install and configure tomcat and java in combination.
#
# Parameters:
#
#  *$java_version*       - The version of Java to be installed, e.g. version 7 or 8. Defaults to 7.
#  *$java_install_dir*   - The base directory where Java is installed in the subdirectory /jdk1.x.0 where x is the *$java_version*. Defaults to /opt.
#  *$platform*           - The machine platform i.e x86 or x64. Defaults to x64.
#  *$tomcat_version*     - Specify tomcat version which you want to install. Defaults to 7.0.53.
#  *$tomcat_install_dir* - The base directory where Tomcat is installed in the subdirectory /jdk1.x.0 where x is the *$tomcat_version*. Defaults to /opt.
#  *$use_cache*          - Use the tarballs for java and tomcat from the puppetmaster instead of the internet. Defaults to *false*.
#  *$env_path*           - The is the bash script which sets JAVA_HOME, and PATH. Defaults to /etc/profile.d/tomcat.sh.
#
# Actions:
#
# Installs both the Java Development Kit and Tomcat,
# sets the *JAVA__HOME* environment variable and appends *JAVA__HOME*/bin to the *PATH*
#
# Requires: see Modulefile
#
# Sample Usage:
#   # to install default versions, Java 7 and Tomcat 7.0.53
#   include 'tomcat'
#
#   # to install specific versions, Java 8 and Tomcat 7.0.53,
#   # using the tarballs from the puppetmaster
#   class { tomcat:
#     java_version   => 8,
#     tomcat_version => '7.0.53',
#     use_cache      => true,
#   }
 class tomcat (
      $java_version       = hiera('tomcat::java_version', '7' ),
      $java_install_dir   = hiera('tomcat::java_install_dir', '/opt' ),
      $platform           = hiera('tomcat::platform', 'x64' ),
      $tomcat_version     = hiera('tomcat::tomcat_version', '7.0.53'),
      $tomcat_install_dir = hiera('tomcat::tomcat_install_dir', '/opt'),
      $use_cache          = hiera('tomcat::use_cache', false ),
      $env_path           = hiera('tomcat::env_path', '/etc/profile.d/tomcat.sh')
      ) {

  Exec { path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin',] }

  file { 'java_install_dir':
    path    => $java_install_dir,
    ensure  => directory,
    owner   => root,
    group   => root,
  }

  case $platform {
    'x64': { $plat_filename = 'x64' }
    'x86': { $plat_filename = 'i586' }
    default: {
      fail( "Unsupported platform: ${platform}." )
    }
  }

  case $java_version {
    '8': {
      $java_download_uri = "http://download.oracle.com/otn-pub/java/jdk/8-b132/jdk-8-linux-${plat_filename}.tar.gz"
      $java_home = "${java_install_dir}/jdk1.8.0"
    }
    '7': {
      $java_download_uri = "http://download.oracle.com/otn-pub/java/jdk/7/jdk-7-linux-${plat_filename}.tar.gz"
      $java_home = "${java_install_dir}/jdk1.7.0"
    }
    default: {
      fail("Unsupported java_version: ${java_version}.")
    }
  }

  $java_installer_filename = inline_template('<%= File.basename(@java_download_uri) %>')

  if ( $use_cache ){
    file { "${java_install_dir}/${java_installer_filename}":
      source  => "puppet:///modules/tomcat/${java_installer_filename}",
    }
    exec { 'get_jdk_installer':
      cwd     => $java_install_dir,
      creates => "${java_install_dir}/jdk_from_cache",
      command => 'touch jdk_from_cache',
      require => File["${java_install_dir}/jdk-${java_version}-linux-x64.tar.gz"],
    }
  }
  else {
    exec { 'get_jdk_installer':
      cwd     => $java_install_dir,
      creates => "${java_install_dir}/${java_installer_filename}",
      command => "wget -c --no-cookies --no-check-certificate --header \"Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com\" --header \"Cookie: oraclelicense=accept-securebackup-cookie\" \"${java_download_uri}\" -O ${java_installer_filename}",
      timeout => 600,
    }
    file { "${java_install_dir}/${java_installer_filename}":
      mode    => '0755',
      owner   => root,
      group   => root,
      require => Exec['get_jdk_installer'],
    }
  }

  if ( $java_version in [ '7', '8' ] ) {
    exec { 'extract_jdk':
      cwd     => "${java_install_dir}/",
      command => "tar -xf ${java_installer_filename}",
      creates => $java_home,
      require => Exec['get_jdk_installer'],
    }
  }

  file { '/opt/java':
    ensure  => link,
    target  => "${java_home}",
    require => Exec['extract_jdk'],
  }

  if ( $java_version in [ '7', '8' ] ) {
    exec { "set_java_home":
      command => "echo 'export JAVA_HOME=/opt/java'>> ${env_path}",
      unless  => "grep 'JAVA_HOME=/opt/java' ${env_path}",
      require => File['/opt/java'],
    }
  }

  exec { "set_java_path":
    command => "echo 'export PATH=\$JAVA_HOME/bin:\$PATH' >> ${env_path}",
    unless  => "grep 'export PATH=\$JAVA_HOME/bin:\$PATH' ${env_path}",
    require => Exec["set_java_home"],
  }

  exec { "set_env":
    command => "bash -c 'source ${env_path}'",
    require => Exec['set_java_path'],
    onlyif  => "echo $PATH | grep '/opt/java/bin'",
  }

  $tomcat_major_version = regsubst($tomcat_version, '\..*', '')
  $tomcat_download_url = "http://archive.apache.org/dist/tomcat/tomcat-${tomcat_major_version}/v${tomcat_version}/bin/apache-tomcat-${tomcat_version}.tar.gz"

  if ( $use_cache ){
    file { "${tomcat_install_dir}/${tomcat_installer_filename}":
      source  => "puppet:///modules/tomcat/${tomcat_installer_filename}",
    }
    exec { 'get_tomcat_installer':
      cwd     => $tomcat_install_dir,
      creates => "${tomcat_install_dir}/tomcat_from_cache",
      command => 'touch tomcat_from_cache',
      require => [ File["${tomcat_install_dir}/${tomcat_installer_filename}"], Exec['set_env'], ],
    }
  }
  else
  {
    exec { 'get_tomcat_installer':
      cwd     => $tomcat_install_dir,
      creates => "${tomcat_install_dir}/apache-tomcat-${tomcat_version}",
      command => "wget -c --no-cookies --no-check-certificate \"${tomcat_download_url}\" -O apache-tomcat-${tomcat_version}.tar.gz",
      timeout => 600,
      require => Exec['set_env'],
    }
  }

  exec { 'extract_tomcat':
    cwd     => $tomcat_install_dir,
    command => "tar xzf 'apache-tomcat-${tomcat_version}.tar.gz' -C ${tomcat_install_dir}",
    unless  => "test -e ${tomcat_install_dir}/apache-tomcat-${tomcat_version}",
    require => Exec['get_tomcat_installer'],
  }

  file { '/opt/tomcat':
    ensure  => link,
    target  => "${tomcat_install_dir}/apache-tomcat-${tomcat_version}",
    require => Exec['extract_tomcat'],
  }
}