#!/bin/bash

##======================================================================
## File: dstar-gantry-build.sh
## Author: Bryan Jurish <jurish@bbaw.de>
## Description:
##  User-level script for docker "dstar-buildhost" container operations
##======================================================================

##======================================================================
## Globals

prog=$(basename "$0")
dstar_root_default=~/dstar
gantry_root=$(dirname $(dirname $(readlink -f "$0")))
gantry_rcfiles=(/etc/dstar-gantry.rc ~/.dstar-gantry.rc)
gantry_version="0.0.7"
gantry_svnid='
  §HeadURL: https://github.com/moocow-the-bovine/dstar-gantry/blob/master/bin/dstar-gantry.sh $
  $Id: dstar-gantry.sh $
'

##======================================================================
## Utils

##--------------------------------------------------------------
show_version() {
    cat <<EOF
$prog v$gantry_version by Bryan Jurish <jurish@bbaw.de>
$gantry_svnid
EOF
}

##--------------------------------------------------------------
show_usage() {
    cat <<EOF >&2

Usage: $prog [GANTRY_OPTS] [GANTRY_ACTION(s)] [-- [DOCKER_OPTS] [-- [BUILD_ARGS]]]

 $prog Options (GANTRY_OPTS):
   -h  , -help           # this help message
   -V  , -version        # show program version and exit
   -n  , -dry-run        # just print what we would do
   -fg , -batch, -bg     # run container in foreground (default), non-interactively, or background
   -rm , -persist        # remove container on termination (default) or don't
   -a  , -no-agent       # run without an ssh-agent connection (not recommended)
   -c CORPUS             # dstar corpus label (required for most operations)
   -d DSTAR_ROOT         # host path for sparse persistent dstar superstructure (default=$dstar_root_default)
   -C CORPUS_ROOT        # host path for dstar corpus checkout (default=DSTAR_ROOT/corpora/CORPUS)
   -S CORPUS_SRC         # host path of dstar corpus sources (default=DSTAR_ROOT/sources/CORPUS if present)
   -R RESOURCES_DIR      # host path for persistent CAB resources (default=DSTAR_ROOT/resources/ if present)
   -RO                   # mount RESOURCES_DIR read-only (suppress resource synchronization by container)
   -f RCFILE             # read gantry variables from RCFILE (bash source)
   -i IMAGE              # use docker image IMAGE (default=$gantry_docker_image)
   -e VAR=VALUE          # environment variables are passed to docker-run(1) -e
   -E ENV_FILE           # environment files are passed to docker-run(1) --env-file
   -v /PATH:/MOUNT       # volume options are are passed to docker-run(1) -v
   -x CABX_RUN           # cabx servers for container 'run' action (default=$gantry_cabrun)
   -p HTTP_PORT          # map container port 80 to host HTTP_PORT for 'run' action
   -u USER               # build user or UID (default=$gantry_user)
   -g GROUP              # build group or GID (default=$gantry_group)

 $prog Actions (GANTRY_ACTION(s)):
   init                  # (re-)initialize persistent sparse local DSTAR_ROOT checkout
   sync-host             # syncronize local DSTAR_ROOT checkout via \`svn update\`
   sync-self             # syncronize local dstar-gantry checkout via \`git pull\` or \`svn update\`
   sync                  # alise for 'sync-host' and 'sync-self'
   pull                  # retrieve selected IMAGE from docker registry (may require \`docker login\`)
   gc                    # clean up stale local dstar-buildhost docker images
   ...                   # other actions are passed to container docker/build script (see below)

 Docker Options (DOCKER_OPTS): see docker-run(1).

 Container docker/build Arguments (BUILD_ARGS; see also dstar/docker/build):
   help                  # show help for container docker/build script
   self-test             # run rudimentary self-test(s)
   checkout              # checkout corpus build superstructure to CORPUS_ROOT/build/
   build                 # index a corpus in CORPUS_ROOT/build from sources in CORPUS_SRC/
   update                # update an existing index in CORPUS_ROOT/build/ from CORPUS_SRC/
   update-meta           # update index metadata in in CORPUS_ROOT/build/ from CORPUS_SRC/
   test                  # test a corpus build in CORPUS_ROOT/build/
   archive-build         # archive CORPUS_ROOT/build/ to \${dstar_archive_dir}
   archive-publish       # archive publishable corpus data to \${dstar_archive_dir}
   install               # install CORPUS_ROOT/build/ to CORPUS_ROOT/{server,web}/
   uninstall             # remove CORPUS_ROOT/{server,web}/
   publish               # deploy CORPUS_ROOT/build/ to production host(s)
   run                   # run CORPUS_ROOT/{server,web}/ corpus instance in container
   freeze                # freeze CORPUS_ROOT/build/ subdirectory (tar cz)
   thaw                  # thaw CORPUS_ROOT/build/ subdirectory (tar xz)
   shell                 # run a bash shell in the container
   exec CMD...           # just execute CMD... in container

 Host Environment Variables:
   SSH_AUTH_SOCK         # (usually required) ssh-agent(1) socket

 Container Environment Variables:
   See \`$prog help\`

EOF
}

##--------------------------------------------------------------
die() {
    echo "$prog: ERROR: $*" >&2
    exit 255
}
vdie() { die "$@"; }

warn() {
    echo "$prog: WARNING: $*" >&2
}
vwarn() { warn "$@"; }

vinfo() {
    echo "$prog: INFO: $*" >&2
}

##--------------------------------------------------------------
runcmd() {
    echo "$prog: CMD:" "${@@Q}" >&2
    [ -n "$gantry_dry_run" ] && return 0
    "$@"
}

runordie() {
    runcmd "$@"
    local rc=$?
    [ $rc -eq 0 ] || die "command \`$*\` exited abnormally with status $rc"
}

runcmd_ro() {
    local _dry_run="$gantry_dry_run"
    gantry_dry_run=""
    runcmd "$@"
    rc=$?
    gantry_dry_run="$_dry_run"
    return $rc
}

runordie_ro() {
    local _dry_run="$gantry_dry_run"
    gantry_dry_run=""
    runordie "$@"
}

##--------------------------------------------------------------
read_rcfile() {
    local rcfile="$1"
    [ -e "$rcfile" ] || die "config-file '$rcfile' is not readable"
    vinfo "reading gantry config-file '$rcfile'"
    . "$rcfile"
}


##======================================================================
## Gantry Actions

##--------------------------------------------------------------
set_dstar_root() {
    if [ -z "$DSTAR_ROOT" ] ; then
	    DSTAR_ROOT=$(readlink -m $dstar_root_default)
	    warn "implicitly setting default DSTAR_ROOT=$DSTAR_ROOT"
    fi
    DSTAR_ROOT=$(readlink -m "$DSTAR_ROOT")
    export DSTAR_ROOT
}

##--------------------------------------------------------------
find_dstar_root() {
    if [ "${DSTAR_ROOT:-no}" = "no" -a -e $dstar_root_default ] ; then
	    DSTAR_ROOT=$(readlink -m $dstar_root_default)
	    vinfo "using default DSTAR_ROOT=$DSTAR_ROOT" # (set DSTAR_ROOT=no to disable)
    elif [ "${DSTAR_ROOT:-no}" = "no" ] ; then
	    warn "DSTAR_ROOT not set and and default $dstar_root_default/ (did you forget to run \`$prog init\`?)"
    else
	    vinfo "using DSTAR_ROOT=$DSTAR_ROOT"
	    DSTAR_ROOT=$(readlink -m "$DSTAR_ROOT")
    fi
    export DSTAR_ROOT
}


##--------------------------------------------------------------
[ -z "$gantry_dstar_svnroot" ] \
    && gantry_dstar_svnroot=svn+ssh://svn.dwds.de/home/svn/dev/ddc-dstar/trunk
act_gantry_init() {
    ##-- initialize: DSTAR_ROOT
    set_dstar_root
    vinfo "init: (re-)initializing sparse persistent DSTAR_ROOT=$DSTAR_ROOT"
    [ -e "$DSTAR_ROOT/.svn" ] \
	    || runordie svn co --depth=files "$gantry_dstar_svnroot" "$DSTAR_ROOT"

    local dir depth
    for dir in resources ; do
	    [ -d "$DSTAR_ROOT/$dir" ] && depth="" || depth="--set-depth=infinity"
	    runordie svn up $depth "$DSTAR_ROOT/$dir"
    done

    for dir in corpora sources doc ; do
	    [ -d "$DSTAR_ROOT/$dir" ] && depth="" || depth="--set-depth=files"
	    runordie svn up $depth "$DSTAR_ROOT/$dir"
    done

    ##-- initialize: permissions
    if [ -n "$gantry_user" -a "$(id -u "$gantry_user")" != "$(id -u)" ] ; then
	    for dir in resources corpora ; do
	        [ -d "$DSTAR_ROOT/$dir" ] || continue
	        vinfo "init: enabling write-permission on $DSTAR_ROOT/$dir for group '$gantry_group'"
	        runordie chgrp -R "$gantry_group" "$DSTAR_ROOT/$dir"
	        runordie chmod -R g+w "$DSTAR_ROOT/$dir"
	    done
    fi

    ##-- initialize: docker login
    #local regurl="${gantry_docker_image%%/*}"
    #if [ "$regurl" != "$gantry_docker_image" ] ; then
    #  vinfo "init: logging in to docker registry at '$gantry_docker_registry'"
    #  runordie docker login "$gantry_docker_registry"
    #fi
}

##--------------------------------------------------------------
svn_wc_url() {
    local wcpath="$1"
    svn info "$wcpath" 2>/dev/null | grep '^URL:' | cut -d' ' -f2-
}
act_gantry_sync_self() {
    ##-- sync: self
    local uppath=$(readlink -f "$gantry_root")
    local upscm=""
    local upurl=""

    ##-- upstream SCM & URL
    if [ -d "$uppath/.git" ] ; then
	    upscm=git
	    upurl=$(git -C "$uppath" config --get remote.origin.url)
    else
	    upscm=svn
	    upurl=$(svn_wc_url "$uppath")
    fi

    ##-- actual sync
    if [ "$upscm" = "git" ] ; then
	    vinfo "updating gantry git clone at \`$uppath' from \`$upurl'"
	    runcmd git -C "$uppath" pull
    elif [ "upscm" = "svn" ] ; then
	    vinfo "updating gantry SVN checkout at \`$uppath' from \`$upurl'"
	    runcmd svn update "$uppath"
    else
	    warn "gantry path path '$uppath' does not appear to be a git or SVN working copy - cannot self-synchronize"
	    return 1
    fi
}

##--------------------------------------------------------------
[ -z "$gantry_docker_registry_path" ] \
    && gantry_docker_registry_path=/dstar
act_gantry_sync_host() {
    ##-- sync: DSTAR_ROOT
    set_dstar_root
    [ -d "$DSTAR_ROOT" ] \
	    || die "sync: missing DSTAR_ROOT=$DSTAR_ROOT (did you forget to run \`$prog init\`?)"
    vinfo "synchronizing host DSTAR_ROOT=$DSTAR_ROOT"
    runordie svn up "$DSTAR_ROOT"
}

##--------------------------------------------------------------
act_gantry_sync() {
    act_gantry_sync_host
    act_gantry_sync_self
}

##--------------------------------------------------------------
act_gantry_pull() {
    ##-- sanity check(s)
    local regurl="${gantry_docker_image%%/*}"
    if [ "$regurl" = "$gantry_docker_image" ] ; then
	    warn "pull: image '$gantry_docker_image' appears to be a local image - NOT pulling from registry"
	    return 0
    fi

    ##-- pull: guts (may fail without prior 'docker login')
    runordie docker pull "$gantry_docker_image"

    ##-- NO: implicit gc (prune dangling dstar-buildhost images)
    #act_gantry_gc
}

##--------------------------------------------------------------
[ -n "$gantry_gc_filter" ] \
    || gantry_gc_filter="-f dangling=true -f label=de.dwds.project.name=dstar-buildhost"
act_gantry_gc() {
    ##-- gc: docker
    vinfo "gc: pruning stale docker images ($gantry_gc_filter)"
    local iids=($(runordie_ro docker images -qa $gantry_gc_filter))
    if [ ${#iids[@]} -eq 0 ] ; then
	    vinfo "gc: no stale docker images found: nothing to remove"
	    return 0
    fi
    runordie docker rmi "${iids[@]}"
}

##======================================================================
## Command-line

gantry_args=()
gantry_docker_opts=()
gantry_build_args=()

##--------------------------------------------------------------
## gantry options
gantry_dry_run=""
#gantry_docker_image="lex.dwds.de:443/dstar/dstar-buildhost:latest"
#gantry_docker_image="docker.zdl.org/dstar/dstar-buildhost:latest"
gantry_docker_image="cudmuncher/dstar/dstar-buildhost:latest"
gantry_corpus=""
gantry_corpus_root="" #$DSTAR_ROOT/corpora/$gantry_corpus
gantry_corpus_src=""  #$DSTAR_ROOT/sources/$gantry_corpus
gantry_cabdir="" #$DSTAR_ROOT/resources
gantry_cabdir_ro=""
gantry_cabrun="dstar-http-9096"
gantry_http_port=""
gantry_rm=(--rm)
gantry_fg=(-ti)

if [ -z "$gantry_user" ] ; then
    gantry_user=$(id -un ddc-admin 2>/dev/null)
    gantry_user=${gantry_user:-${SUDO_USER:-$(id -un)}}
fi
if [ -z "$gantry_group" ] ; then
    gantry_group=$(id -gn ddc-admin 2>/dev/null)
    gantry_group=${gantry_group:-${SUDO_GID:-$(id -gn)}}
fi

##-- default rcfile(s)
for rcfile in "${gantry_rcfiles[@]}"; do
    [ \! -e "$rcfile" ] \
	    || read_rcfile "$rcfile"
done

while [ $# -gt 0 ] ; do
    arg="$1"
    shift
    case "$arg" in
	    ##-- options
	    -h|-help|--help) show_usage; exit 1;;
	    -V|-version|--version) show_version; exit 0;;
	    -n|-no-act|--no-act|-dry-run|--dry-run) gantry_dry_run=y;;
	    -fg|--fg|-foreground|--foreground) gantry_fg=(-ti);;
	    -bg|--bg|-background|--background) gantry_fg=(-d);;
	    -batch) gantry_fg=();;
	    -rm|--rm|-nopersist|--nopersist) gantry_rm=(--rm);;
	    -persist|--persist) gantry_rm=(--rm=false);;
	    -a|-no-agent|--no-agent|-no-ssh-agent|--no-ssh_agent) gantry_ssh_agent="no" ;;
	    -c) gantry_corpus="$1"; shift;;
	    -c*) gantry_corpus="${arg#-c}";;
	    -d) DSTAR_ROOT="$1"; shift;;
	    -d*) DSTAR_ROOT="${arg#-d}";;
	    -C) gantry_corpus_root="$1"; shift;;
	    -C*) gantry_corpus_root="${arg#-c}";;
	    -S) gantry_corpus_src="$1"; shift;;
	    -S*) gantry_corpus_src="${arg#-s}";;
	    -RO) gantry_cabdir_ro=":ro";;
	    -R) gantry_cabdir="$1"; shift;;
	    -R*) gantry_cabdir="${arg#-R}";;
	    -f) read_rcfile "$1"; shift;;
	    -f*) read_rcfile "${arg#-f}";;
	    -i) gantry_docker_image="$1"; shift;;
	    -i*) gantry_docker_image="${arg#-i}";;
	    -e) gantry_docker_opts[${#gantry_docker_opts[@]}]="-e$1"; shift;;
	    -e*) gantry_docker_opts[${#gantry_docker_opts[@]}]="$arg" ;;
	    -E) gantry_docker_opts=("${gantry_docker_opts[@]}" --env-file="$1"); shift;;
	    -E*) gantry_docker_opts=("${gantry_docker_opts[@]}" --env-file="${arg#-E}");;
	    -v) gantry_docker_opts[${#gantry_docker_opts[@]}]="-v$1"; shift;;
	    -v*) gantry_docker_opts[${#gantry_docker_opts[@]}]="$arg" ;;
	    -x) gantry_cabrun="$1"; shift;;
	    -x*) gantry_cabrun="${arg#-x}" ;;
	    -p) gantry_http_port="$1"; shift;;
	    -p*) gantry_http_port="${arg#-p}";;
	    -u) gantry_user="$1"; shift;;
	    -u*) gantry_user="${arg#-u}";;
	    -g) gantry_group="$1"; shift;;
	    -g*) gantry_group="${arg#-g}";;
	    ##
	    ##-- gantry actions
	    gantry-init|host-init|init) gantry_actions[${#gantry_actions[@]}]=act_gantry_init;;
	    gantry-sync|sync) gantry_actions[${#gantry_actions[@]}]=act_gantry_sync;;
	    gantry-sync-host|sync-host|host-sync) gantry_actions[${#gantry_actions[@]}]=act_gantry_sync_host;;
	    gantry-sync-self|sync-self|self-sync) gantry_actions[${#gantry_actions[@]}]=act_gantry_sync_self;;
	    gantry-pull|docker-pull|pull) gantry_actions[${#gantry_actions[@]}]=act_gantry_pull;;
	    gantry-gc|docker-gc|gc) gantry_actions[${#gantry_actions[@]}]=act_gantry_gc;;
	    ##
	    ##-- end-of-options
	    --) break ;;
	    ##
	    ##-- default (-> gantry_build_args)
	    *) gantry_build_args[${#gantry_build_args[@]}]="$arg" ;;
    esac
done
[ -z "$gantry_dry_run" ] || prog="${prog} (DRY-RUN)"

##-- gantry actions
for act in "${gantry_actions[@]}"; do
    "$act" || die "gantry action '$act' failed with status $?"
done


##--------------------------------------------------------------
## docker options
gantry_extra_docker_opts=()
while [ $# -gt 0 ] ; do
    arg="$1"
    shift
    case "$arg" in
	    --) break ;;
	    *) gantry_extra_docker_opts[${#gantry_extra_docker_opts[@]}]="$arg" ;;
    esac
done

##--------------------------------------------------------------
## build args
gantry_extra_build_args=("$@")

##======================================================================
## MAIN

if [ ${#gantry_build_args[@]} -eq 0 -a ${#gantry_extra_build_args[@]} -eq 0 ] ; then
    vinfo "no container actions BUILD_ARG(s) specified: nothing to do."
    exit 0
fi

##-- defaults: DSTAR_ROOT
find_dstar_root

##-- defaults: gantry_corpus , gantry_corpus_root
if [ -z "$gantry_corpus_root" -a -z "$gantry_corpus" ] ; then
    warn "neither CORPUS nor CORPUS_ROOT specified (use the -c or -C options)"
elif [ -z "$gantry_corpus_root" -a -n "$gantry_corpus" ] ; then
    if [ "${DSTAR_ROOT:-no}" = "no" ] ; then
	    ##-- gantry_corpus_root: no persistent DSTAR_ROOT: create in CWD
	    gantry_corpus_root="./$gantry_corpus"
    else
	    ##-- gantry_corpus_root: use persistent DSTAR_ROOT/corpora/
	    gantry_corpus_root="$DSTAR_ROOT/corpora/$gantry_corpus"
    fi
    vinfo "setting CORPUS_ROOT=$gantry_corpus_root"
elif [ -n "$gantry_corpus_root" -a -z "$gantry_corpus" ] ; then
    ##-- gantry_corpus: from user-specified gantry_corpus_root
    gantry_corpus=$(basename "$gantry_corpus_root")
fi

##-- defaults: gantry_corpus_src
if [ -z "$gantry_corpus_src" ] ; then
    if [ "${DSTAR_ROOT:-no}" != "no" -a -n "$gantry_corpus" -a -e "$DSTAR_ROOT/sources/$gantry_corpus" ] ; then
	    ##-- gantry_corpus_src: perfer use persistent DSTAR_ROOT/sources/CORPUS
	    ##  + 2020-07-16: prefer persistent sources to attempted resolution of CORPUS_ROOT/src symlinks
	    ##                (because things break if they're both present)
	    gantry_corpus_src="$DSTAR_ROOT/sources/$gantry_corpus"
	    ## ... and honor sources/CORPUS/current/ convention
	    ## NO: this breaks relative src/ symlinks
	    #[ \! -e "$gantry_corpus_src/curent" ] \
	        #    || gantry_corpus_src="$gantry_corpus_src/current"
    elif [ -h "$gantry_corpus_root/src" ] ; then
	    ##-- gantry_corpus_src: use CORPUS_ROOT/src symlink (only if no persistent sources are present)
	    gantry_corpus_src=$(readlink -f "$gantry_corpus_root/src")
    fi
    if [ -n "$gantry_corpus_src" ] ; then
	    vinfo "setting CORPUS_SRC=$gantry_corpus_src"
    else
	    vwarn "no CORPUS_SRC directory specified (expect trouble if you're trying to (re-)index a corpus)"
    fi
fi

##-- defaults: gantry_cabdir
if [ -z "$gantry_cabdir" -a "${DSTAR_ROOT:-no}" != "no" -a -e "$DSTAR_ROOT/resources" ] ; then
    gantry_cabdir="${DSTAR_ROOT}/resources"
    vinfo "setting RESOURCE_DIR=$gantry_cabdir"
fi
if [ "${gantry_cabdir:-no}" = "no" ] ; then
    vinfo "disabling RESOURCE_DIR volume"
    gantry_cabdir=""
fi

##-- defaults: user+group
[[ "$gantry_user"  == *[^0-9]* ]] && gantry_uid=$(id -u "$gantry_user")  || gantry_uid="$gantry_user"
[[ "$gantry_group" == *[^0-9]* ]] && gantry_gid=$(getent group "$gantry_group" | cut -d: -f3) || gantry_gid="$gantry_group"
[ -n "$gantry_uid" ] || die "unknown host user '$gantry_user'"
[ -n "$gantry_gid" ] || die "unknown host group '$gantry_group'"

##-- sanity check(s)
if [ \! -e "$gantry_corpus_root" ] ; then
    if [[ " ${gantry_build_args[*]} ${gantry_extra_build_args[*]} " == *" "@(checkout|build|"test"|update*|install|uninstall|publish|archive*|run)" "* ]] ; then
	    warn "CORPUS_ROOT=$gantry_corpus_root does not exist; creating"
	    runordie mkdir -p "$gantry_corpus_root"
    else
	    warn "CORPUS_ROOT=$gantry_corpus_root does not exist (continuing anyway, YMMV)"
    fi
fi
if [ -e "$gantry_corpus_root" ] ; then
    if [ "$(stat -c'%u' "$gantry_corpus_root")" != "$gantry_uid" ] ; then
	    warn "CORPUS_ROOT=$gantry_corpus_root is not owned by user gantry_uid=$gantry_uid"
    fi
    if [ "$(stat -c'%g' "$gantry_corpus_root")" != "$gantry_gid" ] ; then
	    warn "CORPUS_ROOT=$gantry_corpus_root is not owned by group gantry_gid=$gantry_gid"
    fi
fi

if [ "${gantry_ssh_agent:-yes}" = "no" ] ; then
    ##-- force disable ssh-agent forwarding from container
    vinfo "ssh-agent forwarding from container disabled by user"
    unset SSH_AUTH_SOCK
else
    [ -n "$SSH_AUTH_SOCK" ] \
	    || die "SSH_AUTH_SOCK variable is unset (is your ssh-agent running?)"
    [ -e "$SSH_AUTH_SOCK" ] \
	    || die "SSH_AUTH_SOCK=$SSH_AUTH_SOCK is missing (is your ssh-agent still running?)"
fi

##-- absolute paths
[ -z "$gantry_corpus_root" ] || gantry_corpus_root=$(readlink -m "$gantry_corpus_root")
[ -z "$gantry_corpus_src" ] || gantry_corpus_src=$(readlink -m "$gantry_corpus_src")
[ -z "$gantry_cabdir" ] || gantry_cabdir=$(readlink -m "$gantry_cabdir")

##-- gantry docker opts: name
gantry_docker_opts[${#gantry_docker_opts[@]}]="--name=dstar-gantry-${gantry_corpus}"

##-- gantry docker opts: ports
[ -z "$gantry_http_port" ] \
    || gantry_docker_opts[${#gantry_docker_opts[@]}]=-p"$gantry_http_port:80"

##-- gantry docker opts: volumes
if [ -n "$SSH_AUTH_SOCK" ] ; then
    gantry_docker_opts[${#gantry_docker_opts[@]}]="-v$SSH_AUTH_SOCK:/tmp/ssh-auth-gantry.sock"
    gantry_docker_opts[${#gantry_docker_opts[@]}]="-eSSH_AUTH_SOCK=/tmp/ssh-auth-gantry.sock"
fi

[ -z "$gantry_cabdir" ] \
    || gantry_docker_opts[${#gantry_docker_opts[@]}]=-v"${gantry_cabdir}:/dstar/resources${gantry_cabdir_ro}"

[ -z "$gantry_corpus_src" ] \
    || gantry_docker_opts[${#gantry_docker_opts[@]}]=-v"${gantry_corpus_src}:/dstar/sources/${gantry_corpus}:ro"

[ -z "$gantry_corpus_root" -o -z "$gantry_corpus" ] \
    || gantry_docker_opts[${#gantry_docker_opts[@]}]=-v"${gantry_corpus_root}:/dstar/corpora/${gantry_corpus}"

##-- gantry docker opts: environment: owner+group
gantry_docker_opts[${#gantry_docker_opts[@]}]="-edstar_build_uid=${gantry_uid}"
gantry_docker_opts[${#gantry_docker_opts[@]}]="-edstar_build_gid=${gantry_gid}"
gantry_docker_opts[${#gantry_docker_opts[@]}]="-eDSTAR_USER=${SUDO_USER:-$(id -un)}" ##-- try to use "real" user-config

##-- gantry docker opts: environment: cabx
[ -z "$gantry_cabrun" ] \
    || gantry_docker_opts[${#gantry_docker_opts[@]}]="-edstar_cabx_run=${gantry_cabrun}"

##-- gantry docker opts: environment: corpus
gantry_docker_opts[${#gantry_docker_opts[@]}]="-edstar_corpora=$gantry_corpus"

##-- guts
cmd=(docker run
     "${gantry_rm[@]}"
     "${gantry_fg[@]}"
     "${gantry_docker_opts[@]}"
     "${gantry_extra_docker_opts[@]}"
     "${gantry_docker_image}"
     "/dstar/docker/build"
     "${gantry_build_args[@]}"
     "${gantry_extra_build_args[@]}")

runcmd "${cmd[@]}"
