#!/bin/bash

cd "$(dirname "$0")" # cd to the directory of this script

# Caminho do repositório (argumento ou padrão)
REST_SERVER_PATH="/mnt/backups/rest-server"

# Porta do servidor REST (Padrão :8000)
REST_SERVER_PORT="8000"

show_help() {
  cat << EOF
Uso: $0 [OPÇÕES]

Opções:
  --path=DIR     Define o diretório de backup (default: $REST_SERVER_PATH)
  --port=PORTA   Define a porta para o Rest Server (default: $REST_SERVER_PORT)
  --help         Mostra esta ajuda e sai

Exemplo:
  $0 --path=/mnt/backups/restic --port=8081
EOF
}

# Parser de argumentos
for arg in "$@"; do
  case $arg in
    --path=*)
      REST_SERVER_PATH="${arg#*=}"
      ;;
    --port=*)
      REST_SERVER_PORT="${arg#*=}"
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "❌ Erro: argumento desconhecido '$arg'"
      echo "Use --help para ver as opções disponíveis."
      exit 1
      ;;
  esac
done

echo "Diretório: $REST_SERVER_PATH"
echo "Porta: $REST_SERVER_PORT"

# Detect sudo or fallback
run_cmd() {
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    "$@"
  fi
}

install_or_update_unix() {
  if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet rest_server; then
    run_cmd systemctl stop rest_server
    echo "Paused rest_server for update"
  fi
  install_unix
}

install_unix() {
  echo "Installing rest_server to /usr/local/bin"
  run_cmd mkdir -p /usr/local/bin
  run_cmd cp "$(ls -1 rest_server | head -n 1)" /usr/local/bin/rest_server
  run_cmd chmod +x /usr/local/bin/rest_server
}

create_systemd_service() {
  if [ ! -d /etc/systemd/system ]; then
    echo "Systemd not found. This script is only for systemd-based systems."
    exit 1
  fi

  if [ -f /etc/systemd/system/rest_server.service ]; then
    echo "Systemd unit already exists. Skipping creation."
    return 0
  fi

  echo "Creating systemd service at /etc/systemd/system/rest_server.service"

  run_cmd tee /etc/systemd/system/rest_server.service > /dev/null <<- EOM
[Unit]
Description=Rest Server
After=syslog.target
After=network.target
Requires=rest_server.socket
After=rest_server.socket

[Service]
Type=simple
# You may prefer to use a different user or group on your system.
User=www-data
Group=www-data
ExecStart=/usr/local/bin/rest_server --path ${REST_SERVER_PATH}
Restart=always
RestartSec=5

# The following options are available (in systemd v247) to restrict the
# actions of the rest_server.

# As a whole, the purpose of these are to provide an additional layer of
# security by mitigating any unknown security vulnerabilities which may exist
# in rest_server or in the libraries, tools and operating system components
# which it relies upon.

# IMPORTANT!
# The following line must be customised to your individual requirements.
ReadWritePaths=${REST_SERVER_PATH}

# Set to `UMask=007` and pass `--group-accessible-repos` to rest_server to
# make created files group-readable
UMask=077

# If your system doesn't support all of the features below (e.g. because of
# the use of an older version of systemd), you may wish to comment-out
# some of the lines below as appropriate.
CapabilityBoundingSet=
LockPersonality=true
MemoryDenyWriteExecute=true
NoNewPrivileges=yes

# As the listen socket is created by systemd via the rest_server.socket unit, it is
# no longer necessary for rest_server to have access to the host network namespace.
PrivateNetwork=yes

PrivateTmp=yes
PrivateDevices=true
PrivateUsers=true
ProtectSystem=strict
ProtectHome=yes
ProtectClock=true
ProtectControlGroups=true
ProtectKernelLogs=true
ProtectKernelModules=true
ProtectKernelTunables=true
ProtectProc=invisible
ProtectHostname=true
RemoveIPC=true
RestrictNamespaces=true
RestrictAddressFamilies=none
RestrictSUIDSGID=true
RestrictRealtime=true
# if your service crashes with "code=killed, status=31/SYS", you probably tried to run linux_i386 (32bit) binary on a amd64 host
SystemCallArchitectures=native
SystemCallFilter=@system-service

# Additionally, you may wish to use some of the systemd options documented in
# systemd.resource-control(5) to limit the CPU, memory, file-system I/O and
# network I/O that the rest_server is permitted to consume according to the
# individual requirements of your installation.
#CPUQuota=25%
#MemoryHigh=bytes
#MemoryMax=bytes
#MemorySwapMax=bytes
#TasksMax=N
#IOReadBandwidthMax=device bytes
#IOWriteBandwidthMax=device bytes
#IOReadIOPSMax=device IOPS, IOWriteIOPSMax=device IOPS
#IPAccounting=true
#IPAddressAllow=

[Install]
WantedBy=multi-user.target
EOM

  echo "Reloading systemd daemon"
  run_cmd systemctl daemon-reload
}

create_launchd_plist() {
  echo "Creating launchd plist at /Library/LaunchAgents/com.rest_server.plist"

  run_cmd tee /Library/LaunchAgents/com.rest_server.plist > /dev/null <<- EOM
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.rest_server</string>
    <key>ProgramArguments</key>
    <array>
    <string>/usr/local/bin/rest_server</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>rest_server_PORT</key>
        <string>127.0.0.1:${REST_SERVER_PORT}</string>
    </dict>
</dict>
</plist>
EOM
}

enable_launchd_plist() {
  echo "Trying to unload any previous version of com.rest_server.plist"
  launchctl unload /Library/LaunchAgents/com.rest_server.plist || true
  echo "Loading com.rest_server.plist"
  launchctl load -w /Library/LaunchAgents/com.rest_server.plist
}

create_rcd_service() {
  echo "Creating rc.d service for FreeBSD"
  local rcd_path="/usr/local/etc/rc.d/rest_server"
  echo "Creating rc.d service at $rcd_path"

  run_cmd tee "$rcd_path" > /dev/null << EOM
#!/bin/sh

# PROVIDE: rest_server
# REQUIRE: NETWORKING
# KEYWORD: shutdown

. /etc/rc.subr

name="rest_server"
path="${REST_SERVER_PATH}"
port="${REST_SERVER_PORT}"
rcvar="rest_server_enable"
pidfile="/var/run/\${name}.pid"
command="/usr/local/bin/rest_server"
command_args="--path=\${path} --listen=:\${port} --no-auth"
log_file="/var/log/rest_server.log"
required_files="\${command}"

load_rc_config \$name
: \${rest_server_enable:="NO"}

start_cmd="\${name}_start"
stop_cmd="\${name}_stop"
status_cmd="\${name}_status"

rest_server_start() {
    /usr/sbin/daemon -f -p \${pidfile} \${command} \${command_args} >> \${log_file}
}

rest_server_stop() {
    if [ -f \${pidfile} ]; then
        kill \$(cat \${pidfile}) && rm -f \${pidfile}
    else
        echo "PID file não encontrado: \${pidfile}"
    fi
}

rest_server_status() {
    if [ -f \${pidfile} ]; then
        if ps -p \$(cat \${pidfile}) > /dev/null 2>&1; then
            echo "\${name} está em execução (PID \$(cat \${pidfile}))"
            return 0
        else
            echo "\${name} não está em execução, mas o PID file existe."
            return 1
        fi
    else
        echo "\${name} não está em execução."
        return 1
    fi
}

load_rc_config \$name
run_rc_command "\$1"
EOM

  run_cmd chmod +x "$rcd_path"
  run_cmd sysrc rest_server_enable=YES
  echo "Starting rest_server rc.d service"
  run_cmd service rest_server restart
}

OS=$(uname -s)
if [ "$OS" = "Darwin" ]; then
  echo "Installing on Darwin"
  install_unix
  create_launchd_plist
  enable_launchd_plist
  run_cmd xattr -d com.apple.quarantine /usr/local/bin/rest_server # remove quarantine flag
elif [ "$OS" = "Linux" ]; then
  echo "Installing on Linux"
  install_or_update_unix
  create_systemd_service
  echo "Enabling systemd service rest_server.service"
  run_cmd systemctl enable rest_server
  run_cmd systemctl start rest_server
elif [ "$OS" = "FreeBSD" ]; then
  echo "Installing on FreeBSD"
  install_unix
  create_rcd_service
else
  echo "Unknown OS: $OS. This script only supports Darwin, Linux, and FreeBSD."
  exit 1
fi
