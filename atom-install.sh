#!/bin/bash

set -e

if [ -f /etc/redhat-release ] && which rpm >/dev/null 2>/dev/null && rpm -qf /etc/redhat-release >/dev/null 2>/dev/null ; then
    PLATFORM='el'
    FLAVOR=$(rpm -qf /etc/redhat-release --qf=%{name})
    FLAVOR=${FLAVOR%-*}
    VERSION_MAJ=$(rpm -qf /etc/redhat-release --qf=%{version})
    VERSION_MIN=$(rpm -qf /etc/redhat-release --qf=%{release})
    VERSION_MIN=${VERSION_MIN%.*}
    VERSION="${VERSION_MAJ}.${VERSION_MIN}"
elif which lsb_release >/dev/null 2>/dev/null && lsb_release -i -s | grep -qi ubuntu ; then
    PLATFORM='ubuntu'
    FLAVOR=$(lsb_release -i -s)
    VERSION=$(lsb_release -r -s)
    VERSION_MAJ=${VERSION%.*}
    VERSION_MIN=${VERSION##*.}
else
    PLATFORM='unknown'
fi

__q() {
    default=$1
    shift
    question=$@
    if [ "$default" == "y" -o "$default" == "Y" -o "$default" == "1" ] ; then
        default=1
        prompt="[Y/n]"
    else
        default=0
        prompt="[y/N]"
    fi
    read -e -p "$question $prompt " -N1 -t60 response </dev/tty
    if [ $default -eq 1 ] ; then
        if echo "$response"|grep -qi "n" ; then
            true
            exit # false
        else
            echo y
            exit
        fi
    else
        if echo "$response"|grep -qi "y" ; then
            echo y
            exit
        else
            true
            exit # false
        fi
    fi
}

q_atom_config="$(__q 1 Ship ATOM preconfigured with preferred settings?)"
q_atom_puppet="$(__q 1 Ship ATOM with Puppet packages?)"
q_atom_git="$(__q 1 Ship ATOM with Git packages?)"
q_atom_md="$(__q 1 Ship ATOM with Markdown packages?)"
q_atom_json="$(__q 1 Ship ATOM with JSON packages?)"
q_atom_minimap="$(__q 1 Ship ATOM with Sublime-style Minimap packages?)"
q_atom_remote="$(__q 1 Ship ATOM with Textmate-style Remote ATOM packages?)"
q_atom_vim="$(__q 0 Ship ATOM with Vim keyboard bindings? Answering no will ship with default user-friendly bindings)"
q_atom_proxy="$(__q 0 Are you behind proxy server?)"

if [ ! -z "$q_atom_proxy" ] ; then
    echo "Not implemented yet" #FIXME
    exit 1
fi

dosudo() {
    echo "Executing as root: $@"
    sudo $@
}

dogem() {
    try=1
    while ! dosudo gem $@ ; do
        [ $try -ge 10 ] && echo "Failing" && exit 1
        [ $try -ne 1 ] && echo "Retry $try: gem $@"
        try=$((try+1))
        sleep 10
    done
}

atom_install_ubuntu() {
    dosudo add-apt-repository -y ppa:webupd8team/atom
    dosudo apt-get -y -qq update
    dosudo apt-get -y -qq install atom g++
}

atom_install_el() {
    if [ ! -f /etc/yum.repos.d/helber-atom.repo ] ; then
        cat <<. | dosudo tee /etc/yum.repos.d/helber-atom.repo
[helber-atom]
name=Copr repo for atom owned by helber
baseurl=https://copr-be.cloud.fedoraproject.org/results/helber/atom/epel-\$releasever-\$basearch/
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://copr-be.cloud.fedoraproject.org/results/helber/atom/pubkey.gpg
enabled=1
enabled_metadata=1
.
    fi
    [ -f /etc/yum.repos.d/epel.repo ] || dosudo rpm -i https://dl.fedoraproject.org/pub/epel/epel-release-latest-${VERSION_MAJ}.noarch.rpm
    which atom >/dev/null 2>/dev/null || dosudo yum -y -d0 install atom gcc-c++
}

atom_install_check() {
    if ! which atom >/dev/null 2>/dev/null ; then
        echo "Package installation has failed"
        exit 1
    fi
}

atom_git_install_ubuntu() {
    [ -z "$q_atom_git" ] && exit
    which git >/dev/null 2>/dev/null || dosudo apt-get -y -qq install git
}

atom_git_install_el() {
    [ -z "$q_atom_git" ] && exit
    which git >/dev/null 2>/dev/null || dosudo yum -y -d0 install git
}

atom_puppet_install_ubuntu() {
    [ -z "$q_atom_puppet" ] && exit
    which puppet >/dev/null 2>/dev/null || dosudo apt-get -y -qq install puppet
    which puppet-lint >/dev/null 2>/dev/null || dosudo apt-get -y -qq install puppet-lint
}

atom_puppet_install_el() {
    [ -z "$q_atom_puppet" ] && exit
    which puppet >/dev/null 2>/dev/null || dosudo yum -y -d0 install puppet
    which puppet-lint >/dev/null 2>/dev/null || dogem install puppet-lint
}

atom_git_install() {
    url=
    rev=$2
    [ -z "$rev" ] && rev=HEAD
    [ -z "$q_atom_git" ] && exit
    if ! which git >/dev/null 2>/dev/null ; then
        echo "Git installation has failed"
        exit 1
    fi
    [ ! -d ~/.atom/local-packages ] && mkdir -p ~/.atom/local-packages
    [ -d ~/.atom/packages/$(basename $1 .git) ] && exit 0
    cd ~/.atom/local-packages
    git clone $1
    cd $(basename $1 .git)
    git checkout HEAD
    git checkout $rev
    apm link .
}

atom_install_packages() {
    if ! which apm >/dev/null 2>/dev/null ; then
        echo "Atom Package Manager (apm) not found"
        exit 1
    fi

    apm install aligner
    apm install highlight-selected
    apm install linter

    [ ! -z "$q_atom_json" ] && apm install colorful-json
    [ ! -z "$q_atom_json" ] && apm install pretty-json
    [ ! -z "$q_atom_json" ] && apm install flatten-json
    [ ! -z "$q_atom_json" ] && apm install jsonlint

    [ ! -z "$q_atom_md" ] && apm install markdown-writer
    [ ! -z "$q_atom_md" ] && apm install markdown-scroll-sync

    [ ! -z "$q_atom_minimap" ] && apm install minimap
    [ ! -z "$q_atom_minimap" ] && apm install minimap-linter

    [ ! -z "$q_atom_remote" ] && apm install remote-atom

    [ ! -z "$q_atom_git" ] && apm install git-blame
    [ ! -z "$q_atom_git" ] && apm install git-plus
    [ ! -z "$q_atom_git" ] && apm install merge-conflicts

    [ ! -z "$q_atom_vim" ] && apm install vim-mode
    [ ! -z "$q_atom_vim" ] && apm install vim-surround
    [ ! -z "$q_atom_vim" ] && apm install ex-mode

    [ ! -z "$q_atom_puppet" ] && apm install language-puppet
    [ ! -z "$q_atom_puppet" ] && apm install aligner-puppet

    [ ! -z "$q_atom_puppet" ] && atom_git_install https://github.com/looneychikun/linter-puppet-lint.git 168990b
    [ ! -z "$q_atom_puppet" ] && atom_git_install https://github.com/asquelt/linter-puppet-parser.git
}

atom_configure() {
    [ -z "$q_atom_config" ] && exit
    [ ! -d ~/.atom ] && mkdir ~/.atom
    cat <<. >~/.atom/config.cson
"*":
  welcome:
    showOnStartup: false
  core:
    audioBeep: false
    themes: [
      "one-light-ui"
      "solarized-light-syntax"
    ]
  editor:
    invisibles: {}
    showInvisibles: true
    preferredLineLength: 140
  minimap:
    plugins:
      linter: true
  "markdown-preview-plus": {}
  linter:
    showErrorPanel: true
  "autocomplete-plus": {}
  "git-plus":
    wordDiff: false
  "git-blame":
    ignoreWhiteSpaceDiffs: true
  "linter-puppet-lint": {}
  "linter-puppet-parser": {}
  "git-diff":
    showIconsInEditorGutter: true
.
}

if [ $UID -eq 0 ] ; then
    echo "This script must not be run as root"
    exit 1
fi

case $PLATFORM in
    el)
        atom_install_el
        atom_install_check
        atom_git_install_el
        atom_puppet_install_el
        atom_install_packages
        atom_configure
        ;;
    ubuntu)
        atom_install_ubuntu
        atom_install_check
        atom_git_install_ubuntu
        atom_puppet_install_ubuntu
        atom_install_packages
        atom_configure
        ;;
    *)
        echo "Unsupported OS"
        exit 1
        ;;
esac

