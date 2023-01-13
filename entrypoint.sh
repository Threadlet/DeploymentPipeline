#!/usb/bin/env bash
set -e

log() {
  echo ">> [local]" $@
}

cleanup() {
  set +e
  log "Killing ssh agent."
  ssh-agent -k
  log "Removing workspace archive."
  rm -f /tmp/workspace.tar.bz2
}
trap cleanup EXIT

log "Packing workspace into archive to transfer onto remote machine."
tar cjvf /tmp/workspace.tar.bz2 --exclude .git .

log "Launching ssh agent."
eval `ssh-agent -s`

if [$CLEANUP_OPTION != 'KEEP']
then
  remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { log 'Removing workspace...'; sudo rm -rf \"\$HOME/prosebit\" ; } ; log 'Creating workspace directory...' ; mkdir -p \"\$HOME/prosebit\" ; log 'Unpacking workspace...' ; tar -C \"\$HOME/prosebit\" -xjv ; trap cleanup exit; log 'Launching docker-compose...' ; cd \"\$HOME/prosebit\" ; log 'Running wizardry...' ; sed -i 's|.:/app|/tmp:/tmp|g' .env* ; sed -i 's|.:/app|/tmp:/tmp|g' docker-compose.yml ; docker-compose up --build -d ; "
else
  remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { log 'Removing workspace...'; sudo rm -rf \"\$HOME/prosebit\" ; } ; log 'Creating workspace directory...' ; mkdir -p \"\$HOME/prosebit\" ; log 'Unpacking workspace...' ; tar -C \"\$HOME/prosebit\" -xjv ; log 'Launching docker-compose...' ; cd \"\$HOME/prosebit\" ; log 'Running wizardry...' ; sed -i 's|.:/app|/tmp:/tmp|g' .env* ; sed -i 's|.:/app|/tmp:/tmp|g' docker-compose.yml ; docker-compose up --build -d ; "
fi

ssh-add <(echo "$SSH_PRIVATE_KEY")

echo ">> [local] Connecting to remote host."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  "$remote_command" \
  < /tmp/workspace.tar.bz2
