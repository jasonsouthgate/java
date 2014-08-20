# Class: java
#
# Installs and configures java.
#
# Parameters:
#
#  *$java_version*       - The version of Java to be installed, e.g. version 7 or 8. Defaults to 7.
#  *$java_install_dir*   - The base directory where Java is installed in the subdirectory /jdk1.x.0 where x is the *$java_version*. Defaults to /opt.
#  *$platform*           - The machine platform i.e x86 or x64. Defaults to x64.
#  *$use_cache*          - Use the tarballs for java and tomcat from the puppetmaster instead of the internet. Defaults to *false*.
#  *$env_path*           - The is the bash script which sets JAVA_HOME, and PATH. Defaults to /etc/profile.d/tomcat.sh.
#
# Actions:
#
# Installs the Java Development Kit
# sets the *JAVA__HOME* environment variable and appends *JAVA__HOME*/bin to the *PATH*
#
# Requires: see Modulefile
#
# Sample Usage:
#   # to install default versions, Java 7
#   include java
#
class java (
  $java_version       = '7',
  $java_install_dir   = '/opt',
  $platform           = 'x64',
  $use_cache          = false,
  $env_path           = '/etc/profile.d/tomcat.sh'
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
      $java_download_uri = "http://download.oracle.com/otn-pub/java/jdk/7u60-b19/jdk-7u60-linux-${plat_filename}.tar.gz"
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
      command => "wget --no-check-certificate --no-cookies --header \"Cookie: oraclelicense=accept-securebackup-cookie\" ${java_download_uri} -O ${java_installer_filename}",
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
}
