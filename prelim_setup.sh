#!/bin/bash
# Change the hostname
sudo hostname "DSYS601-LinuxVM"
# Change the line in ~/.bashrc to uncomment the force_color_prompt setting
# The -i.bak will save the original filename with a .bak extension!
sed -i.bak 's/#force_color_prompt=yes/force_color_prompt=yes/' ~/.bashrc
# Overwrite ~/.bash_aliases with our own list of aliases
echo "alias ug='git add . && git commit -a'" > ~/.bash_aliases
echo "alias ai='apt install'" >> ~/.bash_aliases
echo "alias au='apt update && apt upgrade -y'" >> ~/.bash_aliases
echo "alias ibl='sed -E \"/(^\s*#)|(^\s*$)/d\" ' " >> ~/.bash_aliases
# Re-Read the profile settings to pick up the new changes
. ~/.bashrc
# Exit the shell as you'll need to start a new shell to pick up the settings
echo "Close your terminal and re-open it to pick up the new settings"
