#!/bin/bash

# ***************************************
# *                                     *
# *  NOTE: Before running this script:  *
# *                                     *
# ***************************************

# 1) sudo update-locale LANG=en_US.UTF-8 # then logout/login

# 2) Setup swap space with the following command:
#    sudo dd if=/dev/zero of=/var/swapfile bs=1M count=4096 && sudo chmod 600 /var/swapfile && sudo mkswap /var/swapfile && echo /var/swapfile none swap defaults 0 0 | sudo tee -a /etc/fstab && sudo swapon -a

# 2a) sudo apt-get update
# 2b) sudo apt-get upgrade

# 3) If not installing postgres locally, install psql client-side packages:
#    sudo apt-get install libecpg-dev postgresql-client-common postgresql-client

# 4) Set the following values
#    APP_NAME
#    APP_DOMAIN
#    PUBLIC_KEY_URL

# This Bash script sets up a new Ubuntu 20.04 LTS web server.
# https://github.com/lojic/sysadmin_tools/blob/master/racket-cloud-setup.bash
#
# Copyright (C) 2011-2020 by Brian J. Adkins

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

#------------------------------------------------------------
# Modify values below here
#------------------------------------------------------------

USERNAME=deploy
APP_NAME=
APP_DOMAIN=
NOTIFICATION_EMAIL=  # fail2ban will send emails to this address

# To setup ssh keys, specify a full url containing a public key
# e.g. PUBLIC_KEY_URL=http://yourdomain.com/id_rsa.pub
PUBLIC_KEY_URL=

# Boolean flags 1 => true, 0 => false
CHKROOTKIT=1             # Install chkrootkit root kit checker via apt-get
ECHO_COMMANDS=0          # Echo commands from script
EMACS=1                  # Install Emacs via apt-get
FAIL2BAN=1               # Install fail2ban via apt-get
NGINX=1                  # Install nginx
POSTGRES=0               # Install Postgres database via apt-get
RACKET=1                 # Install Racket
SCREEN=1                 # Install screen via apt-get
SHOREWALL=0              # Install shorewall firewall via apt-get

# Prevent prompts during postfix installation
export DEBIAN_FRONTEND=noninteractive

# To install memcached, specify a RAM amount > 0 e.g. 16
#MEMCACHED_RAM=16
MEMCACHED_RAM=0

TIMEZONE=America/New_York
WWW_DIR=/var/www

#------------------------------------------------------------
# Modify values above here
#------------------------------------------------------------

#------------------------------------------------------------
# Functions
#------------------------------------------------------------

function install_racket() {
  if [ "$RACKET" = 1 ]; then
    display_message "Installing Racket"
    pushd /usr/local/src
    wget https://mirror.racket-lang.org/installers/7.8/racket-7.8-src-builtpkgs.tgz
    tar xzf racket-7.8-src-builtpkgs.tgz
    cd racket-7.8/src
    mkdir build
    cd build
    ../configure
    make
    make install
    ln -s /usr/local/src/racket-7.8/bin/racket /usr/local/bin/racket
    popd
  fi
}

function apt_get_packages_common() {
  display_message "Installing common packages"
  apt-get -y install build-essential dnsutils git-core imagemagick libpcre3-dev \
             libreadline6-dev libssl-dev libxml2-dev locate rsync zlib1g-dev \
             libxslt-dev vim dos2unix
}

function apt_get_packages() {
  display_message "Installing packages"
  apt_get_packages_common

  if [ "$SHOREWALL" = 1 ]; then
    install_shorewall_firewall
  fi

  if [ "$EMACS" = 1 ]; then
    display_message "Installing emacs"
    apt-get -y install emacs-nox
  fi

  if [ "$SCREEN" = 1 ]; then
    display_message "Installing screen"
    apt-get -y install screen
  fi

  if [ "$MEMCACHED_RAM" -gt 0 ]; then
    display_message "Installing memcached"
    apt-get -y install memcached
    sed -i.orig -e "/^-m 64/c-m ${MEMCACHED_RAM}" /etc/memcached.conf
  fi

  if [ "$NGINX" = 1 ]; then
      install_nginx
  fi

  if [ "$RACKET" = 1 ]; then
      apt-get -y install daemonize
  fi

  if [ "$POSTGRES" = 1 ]; then
    install_postgres
  fi

  if [ "$FAIL2BAN" = 1 ]; then
    install_fail2ban
  fi

  display_message "Clean up unneeded packages"
  apt-get -y autoremove
}

function configure_logrotate() {
  cat >> /etc/logrotate.conf <<'EOF'
/usr/local/nginx/logs/*.log {
    missingok
    notifempty
    sharedscripts
    postrotate
        test ! -f /usr/local/nginx/logs/nginx.pid || kill -USR1 `cat /usr/local/nginx/logs/nginx.pid`
    endscript
}
EOF

}

function configure_nginx() {
  rm /etc/nginx/sites-enabled/default
  cp /etc/nginx/nginx.conf /etc/nginx/orig.nginx.conf
  cat > /etc/nginx/nginx.conf <<EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
  worker_connections 768;
  # multi_accept on;
}

http {
  ##
  # Basic Settings
  ##

  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  keepalive_timeout 65;
  types_hash_max_size 2048;
  # server_tokens off;

  # server_names_hash_bucket_size 64;
  # server_name_in_redirect off;

  include /etc/nginx/mime.types;
  default_type application/octet-stream;

  ##
  # SSL Settings
  ##

  ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
  ssl_prefer_server_ciphers on;

  ##
  # Logging Settings
  ##

  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;

  ##
  # Gzip Settings
  ##

  gzip on;
  gzip_disable "msie6";

  # gzip_vary on;
  # gzip_proxied any;
  # gzip_comp_level 6;
  # gzip_buffers 16 8k;
  # gzip_http_version 1.1;
  # gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

  upstream racket {
    server localhost:4311;
  }

  server {
    server_name www.$APP_DOMAIN;
    rewrite ^(.*) http://$APP_DOMAIN\$1 permanent;
  }

  server {
    client_max_body_size 30M;
    listen 80;
    server_name $APP_DOMAIN;

    root /home/$USERNAME/$APP_NAME/current/public;

    try_files \$uri/index.html \$uri.html \$uri @racket;

    location @racket {
      # an HTTP header important enough to have its own Wikipedia entry:
      #   http://en.wikipedia.org/wiki/X-Forwarded-For
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

      # enable this if and only if you use HTTPS, this helps Rack
      # set the proper protocol for doing redirects:
      # proxy_set_header X-Forwarded-Proto https;

      # pass the Host: header from the client right along so redirects
      # can be set properly within the Rack application
      proxy_set_header Host \$http_host;

      # we don't want nginx trying to do something clever with
      # redirects, we set the Host: header above already.
      proxy_redirect off;

      # set "proxy_buffering off" *only* for Rainbows! when doing
      # Comet/long-poll/streaming.  It's also safe to set if you're using
      # only serving fast clients with Unicorn + nginx, but not slow
      # clients.  You normally want nginx to buffer responses to slow
      # clients, even with Rails 3.1 streaming because otherwise a slow
      # client can become a bottleneck of Unicorn.
      #
      # The Rack application may also set "X-Accel-Buffering (yes|no)"
      # in the response headers do disable/enable buffering on a
      # per-response basis.
      # proxy_buffering off;

      proxy_pass http://racket;
    }

    # Rails error pages
    error_page 500 502 503 504 /500.html;
    location = /500.html {
      root /home/$USERNAME/$APP_NAME/current/public;
    }
  }
}

EOF
}

function configure_ntp() {
  echo "/usr/sbin/ntpdate -su time.nist.gov" > /etc/cron.daily/ntpdate
  chmod 755 /etc/cron.daily/ntpdate
}

function configure_timezone() {
  local tz=$1

  if [ $tz ]; then
    sudo timedatectl set-timezone $tz      
  fi
}

# Create new user with user:
# create_user username [ public_key_url ]
function create_user() {
  local username=$1
  local pub_key_url=$2
  display_message "Adding new user ${username}:"
  adduser $username

  # Add user to sudoer lsit
  sed -i.orig "\$a$username ALL=ALL" /etc/sudoers

  # Configure command history
  cp /home/${username}/.bashrc /home/${username}/.bashrc.orig
  sed -i -e '/^HISTSIZE/cHISTSIZE=8192' /home/${username}/.bashrc
  sed -i -e '/^HISTFILESIZE/cHISTFILESIZE=8192' /home/${username}/.bashrc
  sed -i -e '/^HISTCONTROL=ignoredups:ignorespace/cHISTCONTROL=ignoredups:ignorespace:erasedups' /home/${username}/.bashrc

  if [ $pub_key_url ]; then
    # Setup ssh keys
    mkdir /home/${username}/.ssh
    chown ${username}:${username} /home/${username}/.ssh
    wget -O /home/${username}/.ssh/authorized_keys $pub_key_url
    chown ${username}:${username} /home/${username}/.ssh/authorized_keys
    chmod 400 /home/${username}/.ssh/authorized_keys
  fi

  if [ $SCREEN ]; then
    # use C-\ instead of C-a to avoid Emacs conflicts
    echo 'escape \034\034' > /home/${username}/.screenrc
    chown ${username}:${username} /home/${username}/.screenrc
    cat >> /home/${username}/.bashrc <<'EOF'
if [ -z "$STY"  ]; then
  screen -d -R
fi
EOF
  fi
}

function display_message() {
  if [ "$1" ]; then
    echo ' '
    echo '************************************************************'
    echo "$1"
    echo '************************************************************'
    echo ' '
  fi
}

function file_name_from_path() {
  echo ${1##*/}
}

function initialize() {
  # Exit on first error, echo commands
  set -e

  if [ "$ECHO_COMMANDS" = 1 ]; then
      set -x
  fi

  # Set default values
  MEMCACHED_RAM=${MEMCACHED_RAM:-0}
  THTTPD_PORT=${THTTPD_PORT:-0}

  # Elasticsearch requires Java
  if [ "$ELASTICSEARCH" = 1 ]; then
    JAVA=1
  fi
}

function install_fail2ban() {
  display_message "Installing fail2ban"
  apt-get -y install fail2ban
  cp /etc/fail2ban//jail.conf /etc/fail2ban/jail.local
  sed -i -e '/^bantime/cbantime = 1800' /etc/fail2ban/jail.local

  if [ "$NOTIFICATION_EMAIL" ]; then
    sed -i -e "/^destemail/cdestemail = ${NOTIFICATION_EMAIL}" /etc/fail2ban/jail.local
  fi

  /etc/init.d/fail2ban restart
}

function install_nginx() {
  display_message "Installing nginx"
  apt-get -y install nginx
  configure_nginx
  configure_logrotate
}

function install_postgres() {
  display_message "Installing postgresql"
  apt-get -y install libecpg-dev postgresql postgresql-contrib
  su -c psql postgres <<EOF
create role $USERNAME superuser login;
EOF
}

function install_shorewall_firewall() {
  display_message "Installing shorewall firewall"
  apt-get -y install shorewall shorewall-doc

  cat > /etc/shorewall/interfaces <<EOF
#
# Shorewall version 4 - Interfaces File
#
# For information about entries in this file, type "man shorewall-interfaces"
#
# The manpage is also online at
# http://www.shorewall.net/manpages/shorewall-interfaces.html
#
###############################################################################
#ZONE   INTERFACE       BROADCAST       OPTIONS
net     eth0     -          routefilter,tcpflags
#LAST LINE -- ADD YOUR ENTRIES BEFORE THIS ONE -- DO NOT REMOVE
EOF

  cat > /etc/shorewall/policy <<EOF
#SOURCE ZONE   DESTINATION ZONE   POLICY   LOG LEVEL   LIMIT:BURST
\$FW            net                ACCEPT
net            all                DROP     info
all            all                REJECT   info
EOF

  cat > /etc/shorewall/rules <<EOF
#
# Shorewall version 4 - Rules File
#
# For information on the settings in this file, type "man shorewall-rules"
#
# The manpage is also online at
# http://www.shorewall.net/manpages/shorewall-rules.html
#
############################################################################################################################
#ACTION         SOURCE          DEST            PROTO   DEST    SOURCE          ORIGINAL        RATE            USER/   MARK
#                                                       PORT    PORT(S)         DEST            LIMIT           GROUP
#SECTION ESTABLISHED
#SECTION RELATED
SECTION NEW
Web/ACCEPT      net     \$FW
SSH/ACCEPT      net     \$FW
#LAST LINE -- ADD YOUR ENTRIES BEFORE THIS ONE -- DO NOT REMOVE
EOF

  cat > /etc/shorewall/zones <<EOF
#ZONE   TYPE    OPTIONS                 IN                      OUT
#                                       OPTIONS                 OPTIONS
fw      firewall
net     ipv4
EOF

  sed -i.orig -e '/^startup=/cstartup=1' /etc/default/shorewall
}

function epilogue() {
  if [ "$SHOREWALL" = 1 ]; then
    cat <<EOF

Test the firewall via: shorewall safe-start (and verify ssh)
EOF
  fi

  if [ "$RSSH" = 1 ]; then
      cat <<EOF

rssh config file is /etc/rssh.conf
EOF
  fi

  cat <<EOF

Root has been disabled from logging in via ssh.
Use the new user $USERNAME in conjunction with sudo.

Password login has been disabled, you must have your public
key installed in ~/.ssh/authorized_keys

Reboot is recommended to verify processes start properly at boot
EOF
}

# Prevent root login
# Prevent password login
function secure_ssh() {
  display_message 'Securing ssh:'
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig

  # Ensure root can't ssh in
  sed -i -e '/PermitRootLogin/s/yes/no/' /etc/ssh/sshd_config

  # Don't allow password login if public key has been supplied
  if [ "$PUBLIC_KEY_URL" ]; then
    sed -i -e '/^#PasswordAuthentication yes/cPasswordAuthentication no' /etc/ssh/sshd_config
  fi

  # Restart sshd
  service ssh restart
}

function update_ubuntu() {
  display_message "Updating Ubuntu"
  apt-get -y update
  apt-get -y upgrade
}

#------------------------------------------------------------
# Main
#------------------------------------------------------------

display_message 'Begin cloud-setup.bash:'
initialize
display_message 'initialize complete:'
display_message 'update_sources_list complete:'
configure_timezone $TIMEZONE
display_message 'Changing root password:'
passwd # Change root passwd
create_user $USERNAME $PUBLIC_KEY_URL
display_message 'user created:'
secure_ssh
display_message 'ssh secured:'
update_ubuntu
display_message 'ubuntu updated:'
apt_get_packages
display_message 'apt-get packages installed:'
install_racket
configure_ntp
display_message 'ntp configured:'
epilogue
