#!/bin/bash
rpath="$(readlink ${BASH_SOURCE})"
if [ -z "$rpath" ];then
    rpath=${BASH_SOURCE}
fi
pwd=${PWD}
this="$(cd $(dirname $rpath) && pwd)"
# cd "$this"
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

_runAsRoot(){
    cmd="${*}"
    local rootID=0
    if [ "${EUID}" -ne "${rootID}" ];then
        echo -n "Not root, try to run as root.."
        # or sudo sh -c ${cmd} ?
        if eval "sudo ${cmd}";then
            echo "ok"
            return 0
        else
            echo "failed"
            return 1
        fi
    else
        # or sh -c ${cmd} ?
        eval "${cmd}"
    fi
}

rootID=0
function _root(){
    if [ ${EUID} -ne ${rootID} ];then
        echo "Need run as root!"
        exit 1
    fi
}

ed=vi
if command -v vim >/dev/null 2>&1;then
    ed=vim
fi
if command -v nvim >/dev/null 2>&1;then
    ed=nvim
fi
if [ -n "${editor}" ];then
    ed=${editor}
fi
###############################################################################
# write your code below (just define function[s])
# function is hidden when begin with '_'
###############################################################################
set -e
# Correct ME
exeName="genfrontend"
# separated by space or newline,quote item if item including space
declare -a runtimeFiles=(
config.yaml
frontendTemplate
)
# FIX ME
# example: main.GitHash or packageName/path/to/hello.GitHash
gitHashPath=
# FIX ME
# example: main.BuildTime or packageName/path/to/hello.BuildTime
buildTimePath=
# FIX ME
# example: main.BuildMachine or packageName/path/to/hello.BuildMachine
buildMachinePath=
_build(){
    local os=${1:?'missing GOOS'}
    local arch=${2:?'missing GOARCH'}
    if [ -z ${exeName} ];then
        echo "${RED}Error: exeName not set!${NORMAL}"
        exit 1
    fi
    local resultDir="${exeName}-${os}-${arch}"

    if [ ${#runtimeFiles} -eq 0 ];then
        echo "${YELLOW}Warning: runtimeFiles is empty!${NORMAL}"
    fi

    if [ ! -d ${resultDir} ];then
        mkdir -p ${resultDir}
    fi

    ldflags="-w -s"
    if [ -n "${gitHashPath}" ];then
        local gitHash="$(git rev-parse HEAD)"
        ldflags="${ldflags} -X ${gitHashPath}=${gitHash}"
    else
        echo "${YELLOW}Warning: gitHashPath is not set${NORMAL}"
    fi

    if [ -n "${buildTimePath}" ];then
        local buildTime="$(date +%FT%T)"
        ldflags="${ldflags} -X ${buildTimePath}=${buildTime}"
    else
        echo "${YELLOW}Warning: buildTimePath is not set${NORMAL}"
    fi

    if [ -n "${buildMachinePath}" ];then
        local buildMachine="$(uname -s)-$(uname -m)"
        ldflags="${ldflags} -X ${buildMachinePath}=${buildMachine}"
    else
        echo "${YELLOW}Warning: buildMachinePath is not set${NORMAL}"
    fi

    echo "${GREEN}Build ${exeName} to ${resultDir}...${NORMAL}"
    GOOS=${os} GOARCH=${arch} go build -o ${resultDir}/${exeName} -ldflags "${ldflags}" main.go && { echo "${GREEN}Build successfully.${NORMAL}"; } || { echo "${RED}Build failed${NORMAL}"; /bin/rm -rf "${resultDir}"; exit 1; }
    for f in "${runtimeFiles[@]}";do
        cp $f ${resultDir}
    done
}

build(){
    _build darwin amd64
    _build darwin arm64
    _build linux amd64
    _build linux arm64
}

_pack(){
    local os=${1:?'missing GOOS'}
    local arch=${2:?'missing GOARCH'}
    local resultDir="${exeName}-${os}-${arch}"

    _build $os $arch
    tar -jcvf ${resultDir}.tar.bz2 ${resultDir}
    /bin/rm -rf ${resultDir}
}

pack(){
    _pack darwin amd64
    _pack darwin arm64
    _pack linux amd64
    _pack linux arm64
}

em(){
    $ed $0
}

###############################################################################
# write your code above
###############################################################################
function _help(){
    cd ${this}
    cat<<EOF2
Usage: $(basename $0) ${bold}CMD${reset}

${bold}CMD${reset}:
EOF2
    perl -lne 'print "\t$2" if /^\s*(function)?\s*(\S+)\s*\(\)\s*\{$/' $(basename ${BASH_SOURCE}) | perl -lne "print if /^\t[^_]/"
}


case "$1" in
     ""|-h|--help|help)
        _help
        ;;
    *)
        "$@"
esac
