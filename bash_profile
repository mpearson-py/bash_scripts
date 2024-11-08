set -o vi
export EDITOR=vi
export TERM=linux

## Aliases

alias lt='ls -lt | more'
alias env='env | sort'
alias pgus='sudo su - postgres'
alias super='sudo su -'

export HISTTIMEFORMAT="+%Y-%m-%d %T "
export PATH=/bin:$PATH

## PS1

CYAN="\[\e[01;36m\]"
WHITE="\[\e[01;37m\]"
BLUE="\[\e[01;34m\]"
RED="\[\e[31m\]"
TEXT_RESET="\[\e[00m\]"
TIME="\t"
CURRENT_PATH="\W"
ROOT_OR_NOT="\$"
HOST="\h"
USER="\u"

if [[ $( whoami ) = "root" ]]; then
        export PS1="${CYAN}[${RED}${USER}${WHITE}@${RED}${HOST}${WHITE}: ${CURRENT_PATH}${CYAN} ]${TEXT_RESET} $: "
else
        export PS1="${CYAN}[${BLUE}${USER}${WHITE}@${RED}${HOST}${WHITE}: ${CURRENT_PATH}${CYAN} ]${TEXT_RESET} $: "
fi
