#!/bin/bash

sudo apt update
sudo apt install -y apache2
sudo apt install -y git

# Clone the GitHub repository
git clone https://github.com/amolshete/card-website.git


sudo cp -r card-website/* /var/www/html/

