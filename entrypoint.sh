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
  remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { [ \$\? -eq 0 ] && exit ; log 'Removing workspace...'; rm -rf \"\$HOME/frontend\" ; } ; log 'Creating workspace directory...' ; mkdir -p \"\$HOME/frontend\" ; trap cleanup EXIT; log 'Unpacking workspace...' ; tar -C \"\$HOME/frontend\" -xjv ; log 'Launching docker-compose...' ; cd \"\$HOME/frontend\" ; docker-compose -f docker-compose.production.yml up --build -d; exit;"
else
  remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { [ \$\? -eq 0 ] && exit ; log 'Removing workspace...'; rm -rf \"\$HOME/frontend\" ; } ; log 'Creating workspace directory...' ; mkdir -p \"\$HOME/frontend\" ; log 'Unpacking workspace...' ; tar -C \"\$HOME/frontend\" -xjv ; log 'Launching docker-compose...' ; cd \"\$HOME/frontend\" ; docker-compose -f docker-compose.production.yml up --build -d; exit;"
fi

ssh-add <(echo "$SSH_PRIVATE_KEY")

echo ">> [local] Connecting to remote host."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  "$remote_command" \
  < /tmp/workspace.tar.bz2
