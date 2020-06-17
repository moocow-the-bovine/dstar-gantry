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

##======================================================================
## Utils

show_usage() {
    cat <<EOF >&2

Usage: $prog [GANTRY_OPTIONS] [-- [DOCKER_OPTIONS] [-- [CONTAINER_BUILD_ARGS]]]

 Gantry Options:
   -h, -help             # this help message
   -n, -dry-run          # just print what we would do
   -c CORPUS_ROOT        # (required) host path for dstar corpus root checkout
   -s CORPUS_SRC         # host path of dstar corpus sources
   -C CORPUS             # dstar corpus label (default=\$(basename CORPUS_ROOT))
   -r RESOURCES_DIR      # use host CAB-resource directory RESOURCES_DIR
   -i IMAGE              # use docker image IMAGE (default=$gantry_image)
   -e VAR=VALUE          # environment variables are passed to docker-run(1) -e
   -E ENV_FILE           # environment files are passed to docker-run(1) --env-file
   -v /PATH:/MOUNT       # volume options are passed to docker-run(1) -v
   -x CABX_RUN           # cabx servers for container runtime (default=$gantry_cabrun)
   -p HTTP_PORT          # map container port 80 to host HTTP_PORT
   -u USER               # build user or UID (default=$gantry_user)
   -g GROUP              # build group or GID (default=$gantry_group)
   ...                   # other gantry options are passed to container docker/build script

 Docker Options (see also docker-run(1))
   -p HPORT:CPORT        # map host port HPORT to container port CPORT
   -v /PATH:/MOUNT       # mount host /PATH in container at /MOUNT
   -e VAR=VALUE          # set container environment variable
   --env-file=ENV_FILE   # set container environment variables from FILE

 Container docker/build Arguments (see also dstar/docker/build):
   -c, -command          # treat CONTAINER_BUILD_ARGS as raw docker command

   help                  # show help for container docker/build script
   exec CMD...           # just execute CMD... in container
   build                 # index a corpus in CORPUS_ROOT/build from sources in CORPUS_SRC/
   update                # update an existing index in CORPUS_ROOT/build/ from CORPUS_SRC/
   update-meta           # update index metadata in in CORPUS_ROOT/build/ from CORPUS_SRC/
   test                  # test a corpus build in CORPUS_ROOT/build/
   archive-build         # archive CORPUS_ROOT/build/ to \${dstar_archive_dir}
   archive-publish       # archive publishable corpus data to \${dstar_archive_dir}
   install               # install CORPUS_ROOT/build/ to CORPUS_ROOT/{server,web}/
   publish               # deploy CORPUS_ROOT/build/ to production host(s)
   run                   # run CORPUS_ROOT/{server,web}/ corpus instance in container

 Host Environment Variables:
   SSH_AUTH_SOCK         # (required) socket ssh-agent(1) 

 Container Environment Variables:
   see \`$prog help\`

EOF
}

die() {
    echo "$prog: ERROR: $*" >&2
    exit 255
}

warn() {
    echo "$prog: WARNING: $*" >&2
}

##======================================================================
## Command-line

docker_opts=()
build_args=()

##--------------------------------------------------------------
## gantry options
gantry_dry_run=""
gantry_image="dstar-buildhost:latest"
gantry_corpus_root=""
gantry_corpus_src=""
gantry_corpus=""
gantry_cabdir=""
gantry_cabrun="dstar-http-9096"
gantry_http_port=""

if [ -z "$gantry_user" ] ; then
    gantry_user=$(id -un ddc-admin 2>/dev/null)
    gantry_user=${gantry_user:-${SUDO_USER:-$(id -un)}}
fi
if [ -z "$gantry_group" ] ; then
    gantry_group=$(id -gn ddc-admin 2>/dev/null)
    gantry_group=${gantry_user:-${SUDO_GID:-$(id -gn)}}
fi

while [ $# -gt 0 ] ; do
    arg="$1"
    shift
    case "$arg" in
	--) break ;;
	"-h"|"-help"|"--help") show_usage; exit 1;;
	"-n"|"-no-act"|"--no-act"|"-dry-run"|"--dry-run") gantry_dry_run=y;;
	"-c") gantry_corpus_root="$1"; shift;;
	"-c"*) gantry_corpus_root="${arg#-c}";;
	"-s") gantry_corpus_src="$1"; shift;;
	"-s"*) gantry_corpus_src="${arg#-s}";;
	"-C") gantry_corpus="$1"; shift;;
	"-C"*) gantry_corpus="${arg#-C}";;
	"-r") gantry_cabdir="$1"; shift;;
	"-r"*) gantry_cabdir="${arg#-r}";;
	"-i") gantry_image="$1"; shift;;
	"-i*") gantry_image="${arg#-i}";;
	"-e") docker_opts[${#docker_opts[@]}]="-e$1"; shift;;
	"-e"*) docker_opts[${#docker_opts[@]}]="$arg" ;;
	"-E") docker_opts=("${docker_opts[@]}" --env-file="$1"); shift;;
	"-E*") docker_opts=("${docker_opts[@]}" --env-file="${arg#-E}");;
	"-v") docker_opts[${#docker_opts[@]}]="-v$1"; shift;;
	"-v"*) docker_opts[${#docker_opts[@]}]="$arg" ;;
	"-x") gantry_cabrun="$1"; shift;;
	"-x"*) gantry_cabrun="${arg#-x}" ;;
	"-p") gantry_http_port="$1"; shift;;
	"-p"*) gantry_http_port="${arg#-p}";;
	"-u") gantry_user="$1"; shift;;
	"-g") gantry_group="$1"; shift;;
	"-u"*) gantry_user="${arg#-u}";;
	"-g"*) gantry_group="${arg#-g}";;
	*) build_args[${#build_args[@]}]="$arg" ;;
    esac
done

##-- sanity check(s)
if [ -z "$gantry_corpus_root" ] ; then
    warn "no CORPUS_ROOT specified (use the -c option)"
elif [ \! -e "$gantry_corpus_root" ] ; then
    warn "CORPUS_ROOT=$gantry_corpus_root does not exist"
fi
[ -n "$SSH_AUTH_SOCK" ] \
    || die "SSH_AUTH_SOCK variable is unset (is your ssh-agent running?)"
[ -e "$SSH_AUTH_SOCK" ] \
    || die "SSH_AUTH_SOCK=$SSH_AUTH_SOCK is missing (is your ssh-agent still running?)"

##-- absolute paths
[ -z "$gantry_corpus_root" ] || gantry_corpus_root=$(readlink -m "$gantry_corpus_root")
[ -z "$gantry_corpus_src" ] || gantry_corpus_src=$(readlink -m "$gantry_corpus_src")
[ -z "$gantry_cabdir" ] || gantry_cabdir=$(readlink -m "$gantry_cabdir")

##-- defaults
[ -n "$gantry_corpus" ] || gantry_corpus=$(basename "$gantry_corpus_root")

##-- gantry docker opts: name
docker_opts[${#docker_opts[@]}]="--name=dstar-gantry-${gantry_corpus}"

##-- gantry docker opts: ports
[ -z "$gantry_http_port" ] \
    || docker_opts[${#docker_opts[@]}]=-p"$gantry_http_port:80"

##-- gantry docker opts: volumes
docker_opts[${#docker_opts[@]}]="-v$SSH_AUTH_SOCK:/tmp/ssh-auth-gantry.sock"
docker_opts[${#docker_opts[@]}]="-eSSH_AUTH_SOCK=/tmp/ssh-auth-gantry.sock"

[ -z "$gantry_cabdir" ] \
    || docker_opts[${#docker_opts[@]}]=-v"$gantry_cabdir:/dstar/resources:ro"

[ -z "$gantry_corpus_src" ] \
    || docker_opts[${#docker_opts[@]}]=-v"$gantry_corpus_src:/dstar/sources/${gantry_corpus}:ro"

docker_opts[${#docker_opts[@]}]=-v"$gantry_corpus_root:/dstar/corpora/${gantry_corpus}"

##-- gantry docker opts: environment: owner+group
[[ "$gantry_user"  == *[^0-9]* ]] && gantry_uid=$(id -u "$gantry_user")  || gantry_uid="$gantry_user"
[[ "$gantry_group" == *[^0-9]* ]] && gantry_gid=$(id -u "$gantry_group") || gantry_gid="$gantry_group"
[ -n "$gantry_uid" ] || die "unknown host user '$gantry_user'"
[ -n "$gantry_gid" ] || die "unknown host group '$gantry_group'"
docker_opts[${#docker_opts[@]}]="-edstar_build_uid=${gantry_uid}"
docker_opts[${#docker_opts[@]}]="-edstar_build_gid=${gantry_gid}"
docker_opts[${#docker_opts[@]}]="-eDSTAR_USER=${SUDO_USER:-$(id -un)}" ##-- try to use "real" user-config

##-- gantry docker opts: environment: cabx
[ -z "$gantry_cabrun" ] \
    || docker_opts[${#docker_opts[@]}]="-edstar_cabx_run=${gantry_cabrun}"

##-- gantry docker opts: environment: corpus
docker_opts[${#docker_opts[@]}]="-edstar_corpora=$gantry_corpus"


##--------------------------------------------------------------
## docker options
while [ $# -gt 0 ] ; do
    arg="$1"
    shift
    case "$arg" in
	--) break ;;
	*) docker_opts[${#docker_opts[@]}]="$arg" ;;
    esac
done

##--------------------------------------------------------------
## build args
build_args=("${build_args[@]}" "$@")


##======================================================================
## MAIN

cmd=(docker run --rm -ti
     "${docker_opts[@]}"
     "${gantry_image}"
     "/dstar/docker/build"
     "${build_args[@]}")

if [ -n "$gantry_dry_run" ]; then
    echo "${cmd[@]@Q}"
    exit 0
fi

set -o xtrace
exec "${cmd[@]}"
