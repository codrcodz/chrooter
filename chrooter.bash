#!/usr/bin/env bash
##################################
#                                #
#    Creators  Laura McMaster    #
#              Cody Lee Cochran  #
#              Wolf              #
#                                #
#  Maintainer  Cody Lee Cochran  #
#                                #
#     License  MIT               #
#                                #
##################################

# 
#  Instructions
#
#  Ensure there are no other sftp users already on this server.
#  If there are, you may need to modify the script slightly.
#  Otherwise, the sftp chroot settings in sshd_config may not work right.
#
#  Append this to the bottom of /etc/ssh/sshd_config:
#
#  Subsystem     sftp   internal-sftp
#  Match Group sftponly
#      ChrootDirectory /home/sftp_chroot
#      X11Forwarding no
#      AllowTCPForwarding no
#      ForceCommand internal-sftp
#
#
#  Comment-out this line above it:
# 
#  Subsystem       sftp    /usr/libexec/openssh/sftp-server
# 
#
#  Always test your configuration settings and reload ssh to apply:
#
#  sshd -t
#  systemctl reload sshd
#

# Define location of top-level directory of all vhost sub-directories
  _vhosts_tld="/var/www/vhosts"

# If group sftponly does not exist, create it
  getent group sftponly || groupadd sftponly
# Add the sftp_chroot tld for all users
  mkdir /home/sftp_chroot
# Make directory only writeable by root
  chown root:root /home/sftp_chroot
  chmod 755 /home/sftp_chroot
# Find each subdirectory of server vhosts' top-level directory
  for _vhost in $(basename -a $(find ${_vhosts_tld} -maxdepth 1 -type d)); do
    # Strip characters not typically allowed in a domain name
      _username=${_vhost//[^0-9a-zA-Z\-\.]/}
    # Linux users are limited to 32 character usernames
      _username=${_username:0:32}
    # Create user; add to sftponly group & do not provide a valid shell
      adduser -d /home/sftp_chroot/${_username} -s /bin/false -G sftponly ${_username}
    # Setup the user's chroot-jail bind-mount sub-directory
      mkdir -p /home/sftp_chroot/${_username}/${_vhost}
    # Try not to recursively chown, and do not override group permissions
      chown ${_username}:${_username} /home/sftp_chroot/${_username}
    # Try not to recursively chmod
      chmod 700 /home/sftp_chroot/${_username}
    # Create the persistent bind-mount outside the chroot to the vhost directory
      echo "${_vhosts_tld}/${_vhost} /home/sftp_chroot/${_username}/${_vhost} none rw,bind,nobootwait 0 0" >> /etc/fstab
      mount /home/sftp_chroot/${_username}/${_vhost}
    # Create a list of random passwords for each user; save creds to file
      echo "${_username}:$(openssl rand -base64 12)" >> /root/sftp_user_creds.txt
  done

# Secure cred file
  chown 400 /root/sftp_user_creds.txt
# Check for 'chpasswd' util
  which chpasswd || echo "Install chpasswd" && exit 1
# Send creds to chpasswd util to update all sftp user passwords
  chpasswd < /root/sftp_user_creds.txt
