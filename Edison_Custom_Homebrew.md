To set up a local Drupal environment using Homebrew on macOS, follow these steps. You’ll be installing the necessary software, including PHP, MySQL, Apache (or Nginx), and Composer. Once everything is installed, you can set up Drupal.
### Prerequisites:
- Homebrew installed on your macOS.
### Step 1: Install PHP
You can install PHP using Homebrew:
```bash
brew install php
```
After installation, start the PHP service:
```bash
brew services start php
```
### Step 2: Install MySQL
Next, install MySQL:
```bash
brew install mysql
```
After installation, start the MySQL service:
```bash
brew services start mysql
```
You can secure MySQL by running:
```bash
mysql_secure_installation
```
This will guide you through setting up a root password and securing MySQL.
### Step 3: Install Apache (Optional if you don't have it)
You can use Apache, which comes with macOS, or install it using Homebrew:
```bash
brew install httpd
```
Start the Apache service:
```bash
brew services start httpd
```
You can configure Apache to work with PHP by modifying the `httpd.conf` file.
### Step 4: Install Composer
Drupal uses Composer for managing PHP dependencies. Install it using Homebrew:
```bash
brew install composer
```
### Step 5: Create a Drupal Project
You can now create a new Drupal project using Composer:
```bash
composer create-project --repository-url="https://repo.packagist.com/pfizer/" pfizer/{subscription}:dev-dev --stability dev -vvv foldername
```
This will create a `{{subscription}}` directory with the Drupal core, modules, themes, and other essential files.

### Step 6: Set Up a Virtual Host (Apache)
Edit your Apache configuration file to set up a virtual host for your Drupal site:
```bash
sudo nano /usr/local/etc/httpd/httpd.conf
```
Add a new virtual host configuration similar to the following:
```apache
<VirtualHost *:80>
   DocumentRoot "/path/to/my_drupal_site/web"
   ServerName mydrupalsite.local
<Directory "/path/to/my_drupal_site/web">
       AllowOverride All
       Require all granted
</Directory>
</VirtualHost>
```
Replace `/path/to/my_drupal_site/web` with the actual path to your Drupal installation.
Restart Apache:
```bash
brew services restart httpd
```
### Step 7: Modify `/etc/hosts`
To make your local domain work, add the following line to your `/etc/hosts` file:
```bash
127.0.0.1 mydrupalsite.local
```
### Step 8: Create a Database for Drupal
Log in to MySQL and create a database for your Drupal installation:
```bash
mysql -u root -p
```
Then run:
```sql
CREATE DATABASE drupal;
```

### Step 9: Finalize and Test
Once you've installed Drupal, you can start building your site locally. Make sure to restart all services after changes to your configuration files.
```bash
brew services restart php
brew services restart mysql
brew services restart httpd
```
Your local Drupal environment should now be fully set up and ready to use.
Let me know if you run into any issues!
