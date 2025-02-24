#!/bin/bash

set +e

echo "INFO | Running transfer ..."
echo "INFO | if you encounter errors you might have to adjust permissions on the remote server or create a new ${PROJECT_ROOT}/scripts/transfer-custom.sh script ..."

# If transfer-custom.sh exists, run it, otherwise use builtin rsync
if [ -f "$PROJECT_ROOT/scripts/transfer-custom.sh" ]; then
     echo "INFO | Using ${PROJECT_ROOT}/scripts/transfer-custom.sh for transfer ..."
     . $PROJECT_ROOT/scripts/transfer-custom.sh
else
     echo "INFO | Using ${PROJECT_ROOT}/scripts/transfer.sh for transfer ..."
     if [ -z "$TRANSFER_REMOTE_USER" ] || [ -z "$TRANSFER_REMOTE_HOST" ]; then
          echo -e "\n\n\n\n"
          echo "ERROR | TRANSFER_REMOTE_USER or TRANSFER_REMOTE_HOST environment variable not set"
          echo "ERROR | Please export the environment variables TRANSFER_REMOTE_USER=x TRANSFER_REMOTE_HOST=x before running this command eg:"
          echo "export TRANSFER_REMOTE_USER=your-remote-host-ssh-username; export TRANSFER_REMOTE_HOST=your-remote-host-ssh-ip-address;"
          exit 1
     fi

     # Check if /srv/tuoni/scripts/tools exists on remote and rsync
     if ! ssh $TRANSFER_REMOTE_USER@$TRANSFER_REMOTE_HOST '[ -d /srv/tuoni/scripts/tools ]'; then
          echo -e "\n\n\n\n"
          echo "ERROR | /srv/tuoni/scripts/tools not found on remote, does ${TRANSFER_REMOTE_HOST} have tuoni files?"
          exit 1;
     else 
          echo "INFO | /srv/tuoni/scripts/tools found on remote, rsyncing ..."
          rsync -avz --progress "$PROJECT_ROOT/scripts/tools/" "$TRANSFER_REMOTE_USER@$TRANSFER_REMOTE_HOST:/srv/tuoni/scripts/tools"
     fi

     # Rsync the transfer directory
     echo "INFO | deleting remote $TRANSFER_REMOTE_USER@$TRANSFER_REMOTE_HOST:/srv/tuoni/transfer folder ..."
     ssh $TRANSFER_REMOTE_USER@$TRANSFER_REMOTE_HOST 'sudo -E rm -rf /srv/tuoni/transfer'
     
     echo "INFO | recreating remote $TRANSFER_REMOTE_USER@$TRANSFER_REMOTE_HOST:/srv/tuoni/transfer folder ..."
     ssh $TRANSFER_REMOTE_USER@$TRANSFER_REMOTE_HOST 'sudo -E mkdir /srv/tuoni/transfer'
     ssh $TRANSFER_REMOTE_USER@$TRANSFER_REMOTE_HOST 'sudo -E chown $(id -u):$(id -g) -R /srv/tuoni/transfer'

     echo "INFO | rsyncing $PROJECT_ROOT/transfer/ to $TRANSFER_REMOTE_USER@$TRANSFER_REMOTE_HOST:/srv/tuoni/transfer ..."
     rsync -avz --progress "$PROJECT_ROOT/transfer/" "$TRANSFER_REMOTE_USER@$TRANSFER_REMOTE_HOST:/srv/tuoni/transfer"
fi

