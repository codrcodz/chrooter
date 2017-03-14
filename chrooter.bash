#!/usr/bin/env bash

# Define location of top-level directory of all vhost sub-directories
  _vhosts_tld="/var/www/vhosts";

# If group sftponly does not exist, create it
  getent group sftponly || groupadd sftponly;

# Find each subdirectory of server vhosts' top-level directory
  for _vhost in $(basename -a $(find $_vhosts_tld -maxdepth 1 -type d)); do
    # Strip characters not typically allowed in a domain name
      _username=${_vhost//[^0-9a-zA-Z\-\.]/}
    # Linux users are limited to 32 character usernames
      _username=${_username:0:32}
    # Do not assign a home directory, or valid shell
	    useradd -M -s /bin/false -G sftponly ${_username};
	  # Make user's chroot jail
	    mkdir -p /home/${_username}/$_vhost;
	  # Parent directory must be writeable by root only
	    chown root:root /home/${_username};
	    chmod 755 /home/${_username};
	  # Make sure sftp user can access sub-directory in chroot
	    chown ${_username} /home/${_username}/$_vhost;
	  # Create the persistent bind-mount outside the chroot to the vhost directory
	    echo "${_vhosts_tld}/${_vhost}/home/${_username}/$_vhost} none rw,bind,nobootwait 0 0" >> /etc/fstab;
	    mount /home/${_username}/${_vhost};
	  # Create a list of random passwords for each user; save creds to file
	    echo "${_username}:$(openssl rand -base64 12)" >> /root/sftp_user_creds.txt;
  done;

# Secure cred file
  chown 400 /root/sftp_user_creds.txt;
# Check for 'chpasswd' util
  which chpasswd || echo "Install chpasswd" && exit 1
# Send creds to chpasswd util to update all sftp user passwords
  chpasswd < /root/sftp_user_creds.txt
