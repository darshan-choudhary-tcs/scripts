#!/bin/bash
# Author Darshan Choudhary
# Treat unset variables as an error
set -o nounset

# string formatters
if [[ -t 1 ]]
then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_green="$(tty_mkbold 32)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"
  do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

ohai() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}


getbrewpath() {
  if [[ `uname -m` == 'arm64' ]]; then
    PROCESSOR=applesilicon
  else
    PROCESSOR=intel
  fi
}
getbrewpath

echo "${tty_green}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++${tty_reset}"
echo "${tty_green}This script will remove the default Apache provided in MacOS and setup a basic webserver using Homebrew${tty_reset}"
echo "${tty_green}HTTPD${tty_reset}"
echo "${tty_green}PHP 8.1${tty_reset}"
echo "${tty_green}MySQL 5.7${tty_reset}"
echo "${tty_green}mkcert${tty_reset}"
echo "${tty_green}Composer${tty_reset}"
echo "${tty_green}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++${tty_reset}"

# Install the xcode command line tsool.
ohai 'Installing xcode command line tool.'
xcode-select --install

# Download and install homebrew
ohai 'Installing homebrew'
which -s brew
if [[ $? != 0 ]] ; then
  # Install Homebrew
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
else
  brew update
fi

# Initiate brew.
if [[ $PROCESSOR == 'applesilicon' ]] ; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(/usr/local/bin/brew shellenv)"
fi

# # Get the brew installed path.
BREWPATH="$(brew --prefix)"

# Installed brew version
ohai 'Get brew version'
brew --version

# Remove the core apache
ohai 'Removing MacOS apache'
sudo apachectl stop
sudo launchctl unload -w /System/Library/LaunchDaemons/org.apache.httpd.plist 2>/dev/null

ohai 'Installing homebrew packages'

# Installing HTTPD
ohai 'Installing HTTPD'
if brew ls --versions httpd > /dev/null; then
  brew upgrade httpd
else
  brew install httpd --quiet
fi

# Installing PHP
ohai 'Installing PHP'
if brew ls --versions php@8.1 > /dev/null; then
  brew upgrade php@8.1
else
  brew install php@8.1 --quiet
fi

# Install MySQL
ohai 'Installing MySQL'
if brew ls --versions mysql@5.7 > /dev/null; then
  brew upgrade mysql@5.7
else
  brew install mysql@5.7 --quiet
fi

# Install mkcert
ohai 'Installing mkcert for SSL certificates'
if brew ls --versions mkcert > /dev/null; then
  brew upgrade mkcert
else
  brew install mkcert --quiet
fi

# Install composer
ohai 'Installing Composer'
if brew ls --versions composer > /dev/null; then
  brew upgrade composer
else
  brew install composer --quiet
fi

ohai 'Package installation completed'

# Web directory checks.
ohai 'Setting web directory'
if [ ! -d "/var/www" ]
then
  sudo mkdir /var/www
else
  echo "${tty_red}DocumentRoot already exists${tty_reset}"
fi

# Web directory permissions
ohai 'Configuring web directory permissions'
chmod 755 /var/www
cd /var
sudo chown -R $USER:_www www


# Create HTTPD helper directories
ohai 'Configuring apache helper directories'
# Virtualhosts directory
if [ ! -d "$BREWPATH/etc/httpd/vhosts" ]
then
  sudo mkdir $BREWPATH/etc/httpd/vhosts
else
  echo "${tty_red}Virtualhorts directory already exists${tty_reset}"
fi

# Certificates directory
if [ ! -d "$BREWPATH/etc/httpd/certs" ]
then
  sudo mkdir $BREWPATH/etc/httpd/certs
else
  echo "${tty_red}Certificate directory already exists${tty_reset}"
fi

# Logs directory
if [ ! -d "$BREWPATH/etc/httpd/logs" ]
then
  sudo mkdir $BREWPATH/etc/httpd/logs
else
  echo "${tty_red}Logs directory already exists${tty_reset}"
fi

# Setting up default SSL certitificate
ohai 'Setting localhost SSL ceritificate'
cd "$BREWPATH/etc/httpd/certs"
openssl genrsa -aes256 -passout pass:gsahdg -out server.pass.key 4096
openssl rsa -passin pass:gsahdg -in server.pass.key -out server.key
rm server.pass.key
openssl req -new -key server.key -out server.csr
openssl x509 -req -sha256 -days 365 -in server.csr -signkey server.key -out server.crt
sudo mkcert localhost 127.0.0.1

# Add a default virtual host.
ohai 'Setting default virtualhost file'
echo '<VirtualHost *:8443>
  ServerName localhost
  DocumentRoot /var/www

  SSLEngine on
  SSLCertificateFile '$BREWPATH/etc/httpd/certs/localhost+1.pem'
  SSLCertificateKeyFile '$BREWPATH/etc/httpd/certs/localhost+1-key.pem'

  <Directory /var/www>
    AllowOverride All
    Options -Indexes +FollowSymLinks
    Require all granted
  </Directory>

  ErrorLog '$BREWPATH/etc/httpd/etc/httpd/logs/localhost-error_log'
  CustomLog '$BREWPATH/etc/httpd/etc/httpd/logs/localhost-access_log' common

</VirtualHost>' > $BREWPATH/etc/httpd/vhosts/_default.conf

# Configure the httpd conf file.
ohai 'Configuring httpd.conf file'
# Create a httpd override conf file.
echo '# Load all the required modules.
LoadModule socache_shmcb_module lib/httpd/modules/mod_socache_shmcb.so
LoadModule ssl_module lib/httpd/modules/mod_ssl.so
LoadModule vhost_alias_module lib/httpd/modules/mod_vhost_alias.so
LoadModule userdir_module lib/httpd/modules/mod_userdir.so
LoadModule rewrite_module lib/httpd/modules/mod_rewrite.so
LoadModule php_module '$BREWPATH'/opt/php/lib/httpd/modules/libphp.so

# Apache user set to the machine username.
<IfModule unixd_module>
User '$USER'
</IfModule>

# Servername
ServerName localhost

# Override the document root
DocumentRoot "/var/www"
<Directory "/var/www">
  Options FollowSymLinks Multiviews
  MultiviewsMatch Any
  AllowOverride All
  Require all granted
</Directory>

#
# DirectoryIndex: sets the file that Apache will serve if a directory
# is requested.
#
<IfModule dir_module>
  DirectoryIndex index.php index.html
</IfModule>

<FilesMatch \.php$>
  SetHandler application/x-httpd-php
</FilesMatch>

# Include the required vhosts and ssl confs.
Include '$BREWPATH'/etc/httpd/vhosts/*.conf
Include '$BREWPATH'/etc/httpd/extra/httpd-ssl.conf

# Include local default SSL ceritificates.
SSLCertificateFile "'$BREWPATH'/etc/httpd/certs/server.crt"
SSLCertificateKeyFile "'$BREWPATH'/etc/httpd/certs/server.key"' > $BREWPATH/etc/httpd/httpd-local.conf

# Include the overridden conf in main conf file.
echo "# Include the local file.
Include "$BREWPATH"/etc/httpd/httpd-local.conf" >> $BREWPATH/etc/httpd/httpd.conf

echo "======  Optimising PHP ini file for performance ======"
sed -i.bak '/^ *post_max_size/s/=.*/= 512M/' $BREWPATH/etc/php/7.4/php.ini
sed -i.bak '/^ *memory_limit/s/=.*/= -1/' $BREWPATH/etc/php/7.4/php.ini

# Overide the default index file.
echo "<html><body><h1><?php echo 'Hello World'; ?></h1></body></html>" > /var/www/index.php

# Restart apache
brew services restart httpd
sudo apachectl restart

echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "\n${tty_green}Homebrew installation is completed along with formulaes${tty_reset}"
echo "${tty_green}DocumentRoot: /var/www${tty_reset}"
echo "${tty_green}We've installed your MySQL database without a root password. To secure it run: mysql_secure_installation${tty_reset}"
php -i | grep 'Loaded Configuration File'
# Command to start mysql 'mysql.server start' if sql throwing /tmp/mysql.sock error
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

exit 0
