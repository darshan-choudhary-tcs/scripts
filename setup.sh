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
    BREWPATH=/opt/homebrew
    PROCESSOR=applesilicon
  else
    BREWPATH=/usr/local
    PROCESSOR=intel
  fi
}
getbrewpath

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

# Set the brew path variables.

if [[ $PROCESSOR == 'applesilicon' ]] ; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(/usr/local/bin/brew shellenv)"
fi

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
echo "${tty_green}===> Enter the PHP version you want to install.${tty_reset}"
read -r PHPVERSION

if brew ls --versions php@$PHPVERSION > /dev/null; then
  brew upgrade php@$PHPVERSION
else
  brew install php@$PHPVERSION --quiet
fi

# Install MySQL
ohai 'Installing MySQL'
echo "${tty_green}===> Enter the MySQL version you want to install.${tty_reset}"
read -r MYSQLVERSION


if brew ls --versions mysql@$MYSQLVERSION > /dev/null; then
  brew upgrade mysql@$MYSQLVERSION
else
  brew install mysql@$MYSQLVERSION --quiet
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

ohai 'Package installation completer'

# Web directory checks.
ohai 'Setting DocumentRoot'
if [ ! -d "/var/www" ]
then
  sudo mkdir /var/www
  chmod 755 /var/www
  cd /var
  sudo chown -R $USER:_www www
else
  echo "${tty_red}DocumentRoot already exists${tty_reset}"
fi


# Configure the httpd conf file.
ohai 'Configuring httpd.conf file'

# Create a httpd override conf file.
echo '# Load all the required modules.
LoadModule socache_shmcb_module lib/httpd/modules/mod_socache_shmcb.so
LoadModule ssl_module lib/httpd/modules/mod_ssl.so
LoadModule vhost_alias_module lib/httpd/modules/mod_vhost_alias.so
LoadModule userdir_module lib/httpd/modules/mod_userdir.so
LoadModule rewrite_module lib/httpd/modules/mod_rewrite.so
LoadModule php7_module '$BREWPATH'/opt/php@'$PHPVERSION'/lib/httpd/modules/libphp7.so

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
Include '$BREWPATH'/etc/httpd/extra/httpd-vhosts.conf
# Include '$BREWPATH'/etc/httpd/extra/httpd-ssl.conf' > $BREWPATH/etc/httpd/httpd-local.conf

# Add a default virtual host.
echo '<VirtualHost *:8080>
  ServerName localhost
  DocumentRoot "/var/www"
</VirtualHost>' > $BREWPATH/etc/httpd/extra/httpd-vhosts.conf

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
