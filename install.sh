#!/bin/bash
if [ -z "${BASH_SOURCE}" ]; then
    this=${PWD}
    logfile="/tmp/$(%FT%T).log"
else
    rpath="$(readlink ${BASH_SOURCE})"
    if [ -z "$rpath" ]; then
        rpath=${BASH_SOURCE}
    fi
    this="$(cd $(dirname $rpath) && pwd)"
    logfile="/tmp/$(basename ${BASH_SOURCE}).log"
fi

export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

user="${SUDO_USER:-$(whoami)}"
home="$(eval echo ~$user)"

# export TERM=xterm-256color

# Use colors, but only if connected to a terminal, and that terminal
# supports them.
if which tput >/dev/null 2>&1; then
  ncolors=$(tput colors 2>/dev/null)
fi
if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    CYAN="$(tput setaf 5)"
    BOLD="$(tput bold)"
    NORMAL="$(tput sgr0)"
else
    RED=""
    GREEN=""
    YELLOW=""
    CYAN=""
    BLUE=""
    BOLD=""
    NORMAL=""
fi

_err(){
    echo "$*" >&2
}

_command_exists(){
    command -v "$@" > /dev/null 2>&1
}

rootID=0

_runAsRoot(){
    cmd="${*}"
    bash_c='bash -c'
    if [ "${EUID}" -ne "${rootID}" ];then
        if _command_exists sudo; then
            bash_c='sudo -E bash -c'
        elif _command_exists su; then
            bash_c='su -c'
        else
            cat >&2 <<-'EOF'
			Error: this installer needs the ability to run commands as root.
			We are unable to find either "sudo" or "su" available to make this happen.
			EOF
            exit 1
        fi
    fi
    # only output stderr
    (set -x; $bash_c "${cmd}" >> ${logfile} )
}

function _insert_path(){
    if [ -z "$1" ];then
        return
    fi
    echo -e ${PATH//:/"\n"} | grep -c "^$1$" >/dev/null 2>&1 || export PATH=$1:$PATH
}

_run(){
    # only output stderr
    cmd="$*"
    (set -x; bash -c "${cmd}" >> ${logfile})
}

function _root(){
    if [ ${EUID} -ne ${rootID} ];then
        echo "Need run as root!"
        echo "Requires root privileges."
        exit 1
    fi
}

ed=vi
if _command_exists vim; then
    ed=vim
fi
if _command_exists nvim; then
    ed=nvim
fi
# use ENV: editor to override
if [ -n "${editor}" ];then
    ed=${editor}
fi
###############################################################################
# write your code below (just define function[s])
# function is hidden when begin with '_'
###############################################################################
version="v4.2.3"

linkMacAMD64="https://github.com/sunliang711/genfrontend/releases/download/${version}/genfrontend-darwin-amd64.tar.bz2"
linkMacARM64="https://github.com/sunliang711/genfrontend/releases/download/${version}/genfrontend-darwin-arm64.tar.bz2"
linkLinuxAMD64="https://github.com/sunliang711/genfrontend/releases/download/${version}/genfrontend-linux-amd64.tar.bz2"
linkLinuxARM64="https://github.com/sunliang711/genfrontend/releases/download/${version}/genfrontend-linux-arm64.tar.bz2"
install(){
    local dest=${1:?'missing install location'}
    if [ ! -d ${dest} ];then
        echo "Create ${dest}..."
        mkdir -p "${dest}"
    fi
    dest=$(cd ${dest} && pwd)
    echo "${GREEN}Install location: ${dest}${NORMAL}"

    case $(uname) in
        Linux)
            case $(uname -m) in
                x86_64)
                    link=${linkLinuxAMD64}
                    ;;
                aarch64)
                    link=${linkLinuxARM64}
                    ;;
            esac
            ;;
        Darwin)
            link=${linkMacAMD64}
            ;;
    esac

    if [ -z "$link" ];then
        echo "${RED}Cannot get download link,your OS not support!${NORMAL}"
        exit 1
    fi
    local tarFile=${link##*/}
    local dirName=${tarFile%.tar.bz2}

    local downloadDir=/tmp
    if [ -e ${downloadDir}/${tarFile} ];then
        echo "${YELLOW}Use cache file ${downloadDir}/${tarFile}${NORMAL}"
    else
        echo "Download $link..."
        (cd $downloadDir && curl -LO ${link}) && { echo "Download successfully"; } || { echo "Download failed!"; exit 1; }
    fi

    (cd ${downloadDir} && _run "tar -C $dest -xvf ${tarFile}" && echo "${GREEN}Install successfully${NORMAL}" || { echo "${RED}Install failed!${NORMAL}"; exit 1; })
    # rename
    (cd $dest && mv ${dirName} genfrontend)

}

em(){
    $ed $0
}

###############################################################################
# write your code above
###############################################################################
function _help(){
    cd "${this}"
    cat<<EOF2
Usage: $(basename $0) ${bold}CMD${reset}

${bold}CMD${reset}:
EOF2
    # perl -lne 'print "\t$1" if /^\s*(\w+)\(\)\{$/' $(basename ${BASH_SOURCE})
    # perl -lne 'print "\t$2" if /^\s*(function)?\s*(\w+)\(\)\{$/' $(basename ${BASH_SOURCE}) | grep -v '^\t_'
    perl -lne 'print "\t$2" if /^\s*(function)?\s*(\w+)\(\)\{$/' $(basename ${BASH_SOURCE}) | perl -lne "print if /^\t[^_]/"
}

case "$1" in
     ""|-h|--help|help)
        _help
        ;;
    *)
        "$@"
esac
