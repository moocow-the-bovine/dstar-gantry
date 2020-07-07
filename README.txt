NAME
    dstar-gantry - convenience wrapper for container-based dstar corpus
    operations

SYNOPSIS
     dstar-gantry.sh [GANTRY_OPTS] [GANTRY_ACTION(s)] [-- [DOCKER_OPTS] [-- [BUILD_ARGS]]]

     dstar-gantry.sh Options (GANTRY_OPTS):
       -h, -help             # this help message
       -n, -dry-run          # just print what we would do
       -c CORPUS             # dstar corpus label (required for most operations)
       -d DSTAR_ROOT         # host path for sparse persistent dstar superstructure (default=$HOME/dstar)
       -C CORPUS_ROOT        # host path for dstar corpus checkout (default=DSTAR_ROOT/corpora/CORPUS)
       -S CORPUS_SRC         # host path of dstar corpus sources (default=DSTAR_ROOT/sources/CORPUS/(current/) if present)
       -R RESOURCES_DIR      # host path for persistent CAB resources (default=DSTAR_ROOT/resources/ if present)
       -RO                   # mount RESOURCES_DIR read-only (suppress resource synchronization by container)
       -f RCFILE             # read gantry variables from RCFILE (bash source; default=$HOME/.dstar-gantry.rc)
       -i IMAGE              # use docker image IMAGE (default=lex.dwds.de:443/dstar/dstar-buildhost:latest)
       -e VAR=VALUE          # environment variables are passed to docker-run(1) -e
       -E ENV_FILE           # environment files are passed to docker-run(1) --env-file
       -v /PATH:/MOUNT       # volume options are are passed to docker-run(1) -v
       -x CABX_RUN           # cabx servers for container 'run' action (default=dstar-http-9096)
       -p HTTP_PORT          # map container port 80 to host HTTP_PORT for 'run' action
       -u USER               # build user or UID (default=ddc-admin)
       -g GROUP              # build group or GID (default=ddc-admin)

     dstar-gantry.sh Actions (GANTRY_ACTION(s)):
       init                  # (re-)initialize persistent sparse local DSTAR_ROOT checkout
       sync                  # syncronize local DSTAR_ROOT checkout via `svn update`
       pull                  # retrieve selected IMAGE from docker registry (may require `docker login`)
       gc                    # clean up stale local dstar-buildhost docker images
       ...                   # other actions are passed to container docker/build script (see below)

     Docker Options (DOCKER_OPTS): see docker-run(1).

     Container docker/build Arguments (BUILD_ARGS; see also `dstar-gantry.sh help`):
       help                  # show help for container docker/build script
       self-test             # run rudimentary self-test(s)
       build                 # index a corpus in CORPUS_ROOT/build from sources in CORPUS_SRC/
       update                # update an existing index in CORPUS_ROOT/build/ from CORPUS_SRC/
       update-meta           # update index metadata in in CORPUS_ROOT/build/ from CORPUS_SRC/
       test                  # test a corpus build in CORPUS_ROOT/build/
       archive-build         # archive CORPUS_ROOT/build/ to ${dstar_archive_dir}
       archive-publish       # archive publishable corpus data to ${dstar_archive_dir}
       install               # install CORPUS_ROOT/build/ to CORPUS_ROOT/{server,web}/
       publish               # deploy CORPUS_ROOT/build/ to production host(s)
       run                   # run CORPUS_ROOT/{server,web}/ corpus instance in container
       exec CMD...           # just execute CMD... in container

     Useful container mounts under /dstar:
      config/                # global dstar configuration (read-only)
      resources/             # CAB analysis resources (read-only)
      sources/CORPUS/        # corpus TEI-XML sources (read-only)
      corpora/CORPUS/        # corpus instance checkout (read-write, required)
      corpora/CORPUS/config.local
                             # local corpus configuration overrides

     Host Environment Variables:
       SSH_AUTH_SOCK         # (required) ssh-agent(1) socket

     Container Environment Variables:
      SSH_AUTH_SOCK               # ssh-agent socket (should probably be a bind-mount)
      dstar_init_hooks            # default INIT_HOOK_DIRS (=)

      dstar_build_uid             # user-id in host system (=`id -u`)
      dstar_build_gid             # group-id in host system (=`id -g`)
      dstar_build_umask           # umask for build process (=002)

      dstar_corpora               # corpora to operate on (whitespace-separated list)
      dstar_corpus                # alias for dstar_corpora (=)
      dstar_archive_dir           # target directory for archive-* targets (=)

      dstar_sync_resources        # sync resources (auto|no|force; default=auto)
      dstar_sync_rcfiles          # resources to be synchronized (default:empty -> all)
      dstar_checkout_corpus_opts  # options for dstar-checkout-corpus.sh (=-force -local-config)
      dstar_build_sh_opts         # options for CORPUS/build/build.sh (=-echo-preset=make-info)
      dstar_cabx_run              # cabx expanders to run (=dstar-http-9096)
      dstar_relay_conf            # socat relay configuration (=/etc/default/dstar-relay)

      ...                         # all environment variables are passed down to child processes (e.g. make)

DESCRIPTION
    The "dstar-gantry" project provides a thin top-level wrapper script
    ("dstar-gantry.sh") for D* corpus operations using the latest
    "dstar-buildhost" docker image pulled from the ZDL docker registry at
    "https://lex.dwds.de:443". The "dstar-buildhost" docker container
    invoked by "dstar-gantry.sh" can simulate any of the "BUILDHOST"
    <https://kaskade.dwds.de/dstar/doc/README.html#BUILDHOST>, "RUNHOST"
    <https://kaskade.dwds.de/dstar/doc/README.html#RUNHOST>, and/or
    "WEBHOST" <https://kaskade.dwds.de/dstar/doc/README.html#WEBHOST> D*
    host roles, but is mostly intended to act as a (virtual) "BUILDHOST".

    See "INSTALLATION" for instructions on installing "dstar-gantry" on your
    local machine, see "USAGE" for details on the various options and
    arguments, and see "EXAMPLES" for some example "dstar-gantry.sh" calls.

INSTALLATION
    This section describes the installation procedure for debian-based linux
    machines. "dstar-gantry" was developed and tested on an x86_64 machine
    running Debian GNU/Linux 10 (buster). You can probably run gantry on
    other architectures, but I can't tell you how to do that.

  Requirements
    debian packages
         bash
         openssh-client
         subversion

    docker
        You will need docker <https://docs.docker.com/get-docker/> installed
        on your local machine with an appropriate docker storage driver, and
        the requisite permissions
        <https://docs.docker.com/engine/install/linux-postinstall/> for your
        local user account. "dstar-gantry" was developed and tested using
        the "docker-ce" and "docker-ce-client" packages version 19.03.8.

    registry credentials
        If you wish to make use of gantry's "pull" action to acquire the
        lastest "dstar-buildhost" docker image (recommended), you will need
        credentials (username and password) for the ZDL docker registry, and
        will need to manually log into the registry using "docker login"
        <https://docs.docker.com/engine/reference/commandline/login/>:

         $ docker login https://lex.dwds.de:443
         Username: zdl
         Password: XXXXXXX
         Login Succeeded

    ssh-agent
        You will need an accessible ssh-agent
        <https://en.wikipedia.org/wiki/Ssh-agent> for your local user
        account as indicated by the "SSH_AUTH_SOCK" environment variable,
        with at least one registered identity (public+private key-pair).

        In order to avoid password prompts during sparse subversion
        checkouts on the local host (recommended), your ssh identity should
        be authorized for password-free access to "odo.dwds.de", as whatever
        user your "~/.ssh/config" <https://linux.die.net/man/5/ssh_config>
        specifies (by default the same username as on your local machine).

        In order to avoid password prompts during implicit subversion
        operations in the "dstar-buildhost" container invoked by gantry
        (recommended), your ssh identity should be authorized for
        password-free access to "ddc@odo.dwds.de".

        If you wish to make use of gantry's automatic resource
        synchronization features (default, recommended), your identity
        should be authorized for password-free access to
        "${CABRC_RSYNC_USER}@${CABRC_SYNCHOST}" (typically
        "ddc@data.dwds.de").

        In order to publish corpus indices via gantry to remote RUNHOSTs
        and/or WEBHOSTs, your identity will need to be authorized for
        password-free access to "${PUBLISH_DEST}" and/or
        "${WEB_PUBLISH_DEST}" (typically
        "ddc-admin@{data,kaskade}.dwds.de").

        See "dstar/doc/README_ssh.txt"
        <https://kaskade.dwds.de/dstar/doc/README_ssh.html> for more
        details.

  Installation Procedure
    download gantry
        Checkout the gantry project itself from SVN to your local machine,
        for example to $HOME/dstar-gantry:

         $ svn checkout svn+ssh://odo.dwds.de/home/svn/dev/ddc-dstar/docker/gantry/trunk ~/dstar-gantry

        Example output (trimmed):

         A    ~/dstar-gantry/bin
         A    ~/dstar-gantry/bin/dstar-gantry.sh
         ...
         Checked out revision 32806.

    setup PATH
        Put the "dstar-gantry.sh" script in your "PATH" (optional,
        recommended):

         $ export PATH=$PATH:$HOME/dstar-gantry/bin

        ... or just symlink it into some directory already in your "PATH":

         $ sudo ln -s $HOME/dstar-gantry/bin/*.sh /usr/local/bin

    initialize persistent data
        Initialize persistent sparse local dstar checkout in $HOME/dstar:

         $ dstar-gantry.sh init

        Example output (trimmed):

         dstar-gantry.sh: INFO: init: (re-)initializing sparse persistent DSTAR_ROOT=/home/USER/dstar
         dstar-gantry.sh: CMD: svn co --depth=files svn+ssh://odo.dwds.de/home/svn/dev/ddc-dstar/trunk /home/USER/dstar
         A    /home/USER/dstar/.DSTAR_ROOT
         ...
         dstar-gantry.sh: INFO: no container actions BUILD_ARG(s) specified: nothing to do.

    retrieve docker image
        Download the latest "dstar-buildhost" image from the ZDL docker
        registry:

         $ dstar-gantry.sh pull

        Example output (trimmed):

         dstar-gantry.sh: CMD: docker pull lex.dwds.de:443/dstar/dstar-buildhost:latest
         latest: Pulling from dstar/dstar-buildhost
 
         Digest: sha256:e5b47f225619e6b433df0dbcdcdfdfdb93e703893ceb6ed9f78f338e77358a77
         Status: Downloaded newer image for lex.dwds.de:443/dstar/dstar-buildhost:latest
         lex.dwds.de:443/dstar/dstar-buildhost:latest
         dstar-gantry.sh: INFO: no container actions BUILD_ARG(s) specified: nothing to do.

    run self-test
        Run rudimentary self-tests:

         $ dstar-gantry.sh self-test

        Example output (trimmed):

         dstar-gantry.sh: INFO: using DSTAR_ROOT=/home/USER/dstar
         dstar-gantry.sh: WARNING: neither CORPUS nor CORPUS_ROOT specified (use the -c or -C options)
         dstar-gantry.sh: WARNING: no CORPUS_SRC directory specified (expect trouble if you're trying to (re-)index a corpus)
         dstar-gantry.sh: INFO: setting RESOURCE_DIR=/local/home/ddc-dstar/dstar/resources
         dstar-gantry.sh: WARNING: CORPUS_ROOT= does not exist (continuing anyway, YMMV)
         dstar-gantry.sh: CMD: docker run --rm -ti --name=dstar-gantry- -v/run/user/1000/ssh-agent.sock:/tmp/ssh-auth-gantry.sock -eSSH_AUTH_SOCK=/tmp/ssh-auth-gantry.sock -v/local/home/ddc-dstar/dstar/resources:/dstar/resources -edstar_build_uid=1008 -edstar_build_gid=1008 -eDSTAR_USER=moocow -edstar_cabx_run=dstar-http-9096 -edstar_corpora= lex.dwds.de:443/dstar/dstar-buildhost:latest /dstar/docker/build self-test
         ...
         build INFO: running self-test(s)
         build INFO: TEST: checking for ssh-agent socket (dstar-nice.sh test -w '/tmp/ssh-agent-wrap.sock')
         build INFO: TEST: checking for ssh-agent identity (test -n "`dstar-nice.sh ssh-add -l | fgrep -v \"no identities\"`")
         build INFO: TEST: svn+ssh access (dstar-nice.sh svn st -u .DSTAR_ROOT)
         Status against revision:  32806
         build INFO: TEST: sync resources (dstar-nice.sh make -C resources sync-test)
         make: Entering directory '/home/ddc-dstar/dstar/resources'
         make: Leaving directory '/home/ddc-dstar/dstar/resources'
         build INFO: TEST: publish to default runhost (ssh "ddc-admin@data.dwds.de" /bin/true)
         build INFO: TEST: publish to default webhost (ssh "ddc-admin@kaskade.dwds.de" /bin/true)
         build INFO: self-test: all tests passed (6/6)

USAGE
     dstar-gantry.sh [GANTRY_OPTS] [GANTRY_ACTION(s)] [-- [DOCKER_OPTS] [-- [BUILD_ARGS]]]

    The "dstar-gantry.sh" wrapper script is a command-line tool in the UNIX
    tradition, and as such accepts a number of options and arguments:

    GANTRY_OPTS
        "GANTRY_OPTS" options are interpreted by the "dstar-gantry.sh"
        script itself, including some convenience wrappers for some common
        "Docker Options".

    GANTRY_ACTION(s)
        GANTRY_ACTION(s) indicate which operation(s) are to be performed,
        typically corresponding directly to the "Container Actions" of the
        same name.

    DOCKER_OPTS
        "DOCKER_OPTS" are passed to the "docker-run"
        <https://docs.docker.com/engine/reference/run/> subprocess.

    BUILD_ARGS
        "BUILD_ARGS" are passed to the "/dstar/docker/build" script in the
        invoked "dstar-buildhost" container.

  Gantry Options
   -h, -help
    Display a brief help message.

   -n, -dry-run
    If specified, just prints what would have been done, but doesn't perform
    any destructive actions.

   -c CORPUS
    Specifies the dstar corpus label ("collection label") for the operand
    corpus. Required for most operations.

   -d DSTAR_ROOT
    Specifies the host path used for (sparse) persistent dstar
    superstructure (default="$HOME/dstar"). By default, persistent CAB
    resources and index data will be created here. The directory will be a
    sparse checkout of the "dstar
    project|https://kaskade.dwds.de/dstar/doc/README.html#Project-Directory-
    Structure" containing only partial checkouts of the "doc/"
    <https://kaskade.dwds.de/dstar/doc/README.html#doc>, "corpora/"
    <https://kaskade.dwds.de/dstar/doc/README.html#corpora>, "sources/"
    <https://kaskade.dwds.de/dstar/doc/README.html#sources>, and
    "resources/" <https://kaskade.dwds.de/dstar/doc/README.html#resources>
    subdirectories.

   -C CORPUS_ROOT
    Specifies the host path used for dstar corpus checkout
    (default="DSTAR_ROOT/corpora/CORPUS"). Implies "-v
    CORPUS_ROOT:/dstar/corpora/CORPUS".

   -S CORPUS_SRC
    Specifies the host path where dstar corpus sources reside
    (default="DSTAR_ROOT/sources/CORPUS/current/" if present, otherwise
    "DSTAR_ROOT/sources/CORPUS/" if present, otherwise required). Implies
    "-v CORPUS_SRC:/dstar/sources/CORPUS:ro".

   -R RESOURCES_DIR
    Specifies the host path for persistent CAB resources
    (default="DSTAR_ROOT/resources/" if present). Implies "-v
    RESOURCES_DIR:/dstar/resources".

   -RO
    If the "-RO" option is specified and "RESOURCES_DIR" is present on the
    local machine, then "RESOURCES_DIR" will be mounted read-only in the
    container, which suppresses resource synchronization in the running
    container. If you want each container invocation to ensure that its CAB
    resources are fully up-to-date, you should NOT use this option. It can
    be useful to bypass synchronization overhead, minimize network
    bandwidth, and ensure resource consistency for post-hoc updates of
    existing corpora though. Use with consideration.

   -f RCFILE
    Reads gantry configuration variables from "RCFILE" on the host machine.
    "RCFILE" is evaluated as bash source; default="$HOME/.dstar-gantry.rc".

   -i IMAGE
    Specifies the docker image to be pulled and/or invoked via "docker run"
    <https://docs.docker.com/engine/reference/run/>. Default is
    "lex.dwds.de:443/dstar/dstar-buildhost:latest".

   -e VAR=VALUE
    Specify an environment variable override for the container via "docker
    run -e VAR=VALUE"
    <https://docs.docker.com/engine/reference/run/#env-environment-variables
    >.

   -E ENV_FILE
    Specify a file containing environment variable overrides for the
    container, via "docker run --env-file ENV_FILE"
    <https://docs.docker.com/engine/reference/run/#env-environment-variables
    >.

   -v /PATH:/MOUNT
    Mounts the host directory "/PATH" as a volume into the container at
    "/MOUNT", passed to "docker_run -v"
    <https://docs.docker.com/engine/reference/run/#volume-shared-filesystems
    >.

    Potentially useful volume mounts "/MOUNT" include:

      /dstar/config/            # global dstar configuration (read-only)
      /dstar/resources/         # CAB analysis resources (read-only)

   -x CABX_RUN
    Select container-internal CAB server(s) to start for container run
    action; default="dstar-http-9096".

   -p HTTP_PORT
    Map containers port 80 to host port "HTTP_PORT" for "run" action via
    "docker run -p HTTP_PORT:80"
    <https://docs.docker.com/engine/reference/run/#expose-incoming-ports>.

   -u USER
    Specifies username or UID of host build user (default="ddc-admin" if
    present, otherwise current user). If the UID does not exist in the
    container (it probably doesn't), it will be created.

   -g GROUP
    Specifies group name or GID of host build user (default="ddc-admin" if
    present, otherwise current group). If the GID does not exist in the
    container (it probably doesn't), it will be created.

  Gantry Actions
   init
    (Re-)initializes persistent sparse local "DSTAR_ROOT" checkout on the
    local host (usually "$HOME/dstar"). You should only have to call this
    once per host, before performing any other "dstar-gantry.sh" actions.

   sync
    Synchronizes the persistent sparse local "DSTAR_ROOT" checkout on the
    local host (usually "$HOME/dstar") via `svn update`. You should
    typically call this before each "dstar-gantry.sh" session, in order to
    ensure that your "DSTAR_ROOT" checkout is up-to-date.

    Note that this action does NOT synchronize gantry itself (maybe it will
    someday), so to ensure that your "dstar-gantry.sh" project is
    up-to-date, you should update it manually:

     $ svn update ~/dstar-gantry

   pull
    Retrieves the selected "dstar-buildhost" IMAGE from the ZDL docker
    registry. May require a preceding "docker login".

   gc
    Cleans up stale "dstar-buildhost" docker images on the local host.

   BUILD_ACTION...
    Other non-option arguments (not beginning with a dash "-") are passed
    verbatim as "Container Actions" to the "/dstar/docker/build" script in
    the suborinate container.

  Docker Options
    Docker options following the first "--" on the "dstar-gantry.sh"
    command-line are passed verbatim to the "docker run"
    <https://docs.docker.com/engine/reference/run/> subprocess for the
    selected "dstar-buildhost" IMAGE. If you need to tweak the "docker run"
    call with more than the "-e VAR=VALUE", "-E ENV_FILE", or "-v
    /PATH:/MOUNT" options, this is how to do it.

  Container Actions
    All arguments following the second "--" on the "dstar-gantry.sh"
    command-line are passed verbatim to the "/dstar/docker/build" script
    call in the subordinate "dstar-buildhost" container. See the output of
    "dstar-gantry.sh help" for a synopsis of the "/dstar/docker/build"
    calling conventions.

   help
    Shows a brief help message from the container "/dstar/docker/build"
    script.

   self-test
    Runs some rudimentary self-test(s) and reports results. Not all
    self-tests need to pass in order for "dstar-gantry.sh" to be useful; the
    functionality you need depends on what you're trying to do and your
    personal preferences.

   build
    (Re-)indexes a corpus in "CORPUS_ROOT/build/" from TEI-XML sources in
    "CORPUS_SRC/". This is basically a wrapper for
    "dstar-checkout-corpus.sh"
    <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Checkout> and
    "CORPUS_ROOT/build/build.sh -build"
    <https://kaskade.dwds.de/dstar/doc/HOWTO.html#build.sh-and-cron-autobuil
    d.sh>, i.e. a full corpus re-build
    <https://kaskade.dwds.de/dstar/doc/talks/corpus-ops-2019/#howto-build>.

   update
    Updates an existing corpus index in "CORPUS_ROOT/build/" from TEI-XML
    sources in "CORPUS_SRC/". This is basically a wrapper for
    "dstar-checkout-corpus.sh"
    <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Checkout> and
    "CORPUS_ROOT/build/build.sh -update"
    <https://kaskade.dwds.de/dstar/doc/HOWTO.html#build.sh-and-cron-autobuil
    d.sh>, i.e. incremental corpus update
    <https://kaskade.dwds.de/dstar/doc/talks/corpus-ops-2019/#howto-update>

   update-meta
    Updates metadata for an existing corpus index in "CORPUS_ROOT/build"
    from TEI-XML sources in "CORPUS_SRC/". This is basically a wrapper for
    "dstar-checkout-corpus.sh"
    <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Checkout> and
    "CORPUS_ROOT/build/build.sh -update-meta"
    <https://kaskade.dwds.de/dstar/doc/HOWTO.html#build.sh-and-cron-autobuil
    d.sh>, i.e. corpus metadata update
    <https://kaskade.dwds.de/dstar/doc/HOWTO_build.html#Consistency-Testing>
    .

   test
    Runs automated consistency tests for an existing corpus build in
    "CORPUS_ROOT/build/test/". This is basically a wrapper for
    "dstar-checkout-corpus.sh"
    <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Checkout> and
    "CORPUS_ROOT/build/build.sh -test"
    <https://kaskade.dwds.de/dstar/doc/HOWTO.html#build.sh-and-cron-autobuil
    d.sh>, i.e. corpus consistency tests
    <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Consistency-Tests>.

   archive-build
    Archives an existing "CORPUS_ROOT/build/" to "${dstar_archive_dir}" if
    set, otherwise to the (corpus-specific) directory specified by the
    "ARC_BUILD_DIR" dstar make variable; usually "CORPUS_ROOT/archive/".

   archive-publish
    Archives publishable corpus data from "CORPUS_ROOT/build/" to
    "${dstar_archive_dir}" if set, otherwise to the (corpus-specific)
    directory specified by the "ARC_PUBLISH_DIR" dstar make variable;
    usually "CORPUS_ROOT/archive/".

   install
    Installs an existing corpus index from "CORPUS_ROOT/build/" to
    "CORPUS_ROOT/{server,web}/" within the running "dstar-buildhost"
    container.

   publish
    Deploy an existing corpus index from "CORPUS_ROOT/build/" to production
    host(s) as selected by the dstar make variables "PUBLISH_DEST" and/or
    "WEB_PUBLISH_DEST".

   run
    Runs a "CORPUS" instance from "CORPUS_ROOT/{server,web}/" in the
    temporary container. For this action, you will probably also want to
    specify "-p HTTP_PORT". If specified, this must be the last container
    action executed.

   exec CMD
    Just executs "CMD..." in the subordinate container. If specified, this
    must be the final container action executed. Use with extreme caution.

  Container Environment Variables
    The following environment variables influence operations in the
    subordinate "dstar-buildhost" container:

   SSH_AUTH_SOCK
    The communication socket for ssh-agent on the docker host will be
    bind-mounted into the container as "/tmp/ssh-auth-gantry.sock". The
    embedded "/dstar/docker/build" script will typically take care of
    wrapping that socket as "/tmp/ssh-agent-wrap.sock", to ensure
    appropriate permissions for the build USER and GROUP within the
    container itself.

   dstar_init_hooks
    Default initialization hook directory for the embedded
    "/dstar/docker/build" script; typically empty. If you need to perform
    additional actions on the container startup, you can set this variable
    to the container path of a (mounted) directory containing hooks
    appropriate for the "run-parts"
    <https://manpages.debian.org/buster/debianutils/run-parts.8.en.html>
    system utility. If no INIT_HOOK_DIR(s) are specified on the command-line
    or by this environment variable, hooks are run from any directory
    matching

     /home/ddc-dstar/dstar/docker/build.d/
     /opt/dstar-build*/

   dstar_build_uid
    Numeric UID of build user; should be automatically populated by gantry
    from the "-u USER" option. If no user with this UID exists in the
    container (likely), a temporary user "dstar-build" will be created
    during container startup.

   dstar_build_gid
    Numeric GID of build group; should be automatically populated by gantry
    from the "-g GROUP" option. If no group with this GID exists in the
    container (likely), a temporary group "dstar-build" will be created
    during container startup and the "dstar_build_uid" user approrpriately
    modified.

   dstar_build_umask
    Specifies the permissions umask for the build process. The default is
    typically specified in the "dstar-buildhost" docker image itself as 002,
    which creates new files with the group-writable flag set. If you're
    feeling paranoid, you can set this to 022 or even 077, but you may
    encounter problems down the line.

   dstar_corpora
    Specifies the corpus or corpora to operate on as a whitespace-separated
    list. Typcically set by "dstar-gantry.sh" itself to "CORPUS". You
    probably don't want to set this yourself.

   dstar_corpus
    Alias for "dstar_corpora".

   dstar_archive_dir
    Target directory for and actions. Empty (unset) by default.

   dstar_sync_resources
    Whether or not to synchronize CAB resources to "RESOURCES_DIR" on
    container startup. Accepts values "auto" (default), "no", and "force".
    The default value ("auto") will only attempt to synchronize resources if
    "RESOURCES_DIR" is not mounted read-only.

   dstar_sync_rcfiles
    Specifies which CAB resources in "RESOURCES_DIR" are to by synchronized
    on container startup. If set and non-empty, overrides that value of the
    dstar make variable "CABRC_FILES" for the implicit "make -C
    /dstar/resources sync" syncronization call. Empty by default, which uses
    the default value for "CABRC_FILES", and should cause all default CAB
    resources to be synchronized.

   dstar_checkout_corpus_opts
    Specifies options for "dstar-checkout-corpus.sh"
    <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Checkout> as
    implicitly called prior to any corpus operation. Default: "-force
    -local-config".

   dstar_build_sh_opts
    Specifies options for "CORPUS_ROOT/build/build.sh -build"
    <https://kaskade.dwds.de/dstar/doc/HOWTO.html#build.sh-and-cron-autobuil
    d.sh>. Default: "-echo-preset=make-info".

   dstar_cabx_run
    Specifies which CAB server(s) to start in the container for the action
    as a whitespace-separated list. CAB server(s) are identified by the file
    basename up to the first dot (".") of the corresponding configuration
    file "/dstar/cabx/*.rc". Default: "dstar-http-9096". Known values:

     dstar-http-9096       - runtime expansion for synchronic German
     dstar-http-dta-8088   - runtime expansion for historical German
     dstar-http-dta-9099   - "public" web-service for historical German
     dstar-http-en-9097    - runtime expansion for synchronic English
     dstar-http-taghx-9098 - runtime lemma-equivalence using TAGH

   dstar_relay_conf
    Specifies container path containing "socat"
    <https://linux.die.net/man/1/socat> relay configuration for
    "/dstar/init/dstar-relay.sh". Empty by default, which starts no relays.
    This option is useful for workstations with insufficient resources to
    run embedded CAB expansion servers locally, or in situations where
    "RESOURCES_DIR" is not fully populated in order to bind "virtual" local
    ports which forward all requests to a remote server daemon (e.g.
    "data.dwds.de:9096" for the CAB expansion server "dstar-http-9096"). It
    can also be useful for testing "metacorpora" in a container without
    having to run all daughter corpora in the container as well; in this
    case, relays should be defined for each immediate daughter node of the
    metacorpus to be run.

    See "dstar-buildhost:/dstar/init/etc_default_dstar_relay"
    <http://odo.dwds.de/websvn/filedetails.php?repname=D%2A%3A+Dev-Repositor
    y&path=%2Fddc-dstar%2Ftrunk%2Finit%2Fetc_default_dstar_relay> for syntax
    and more details.

   VAR
    All environment variables are passed down to child processes (e.g.
    "dstar-nice.sh"
    <https://kaskade.dwds.de/dstar/doc/HOWTO.html#dstar-nice-sh>, "make");
    see "Customizable Variables" in "README_build.txt"
    <https://kaskade.dwds.de/dstar/doc/README_build.html#Customizable-Variab
    les> for more (non-exhaustive) details.

EXAMPLES
  TODO CONTINUE HERE
CAVEATS
  docker storage drivers
    Problems with runtime cross-layer copy operations have been observed
    using the "overlay2" docker storage driver, which is the default in
    recent version of the "docker-ce" package. The "aufs" docker storage
    driver does not exhibit these problemes; see
    <https://docs.docker.com/storage/storagedriver/aufs-driver/> for
    details. Typically, the "aufs" driver can be enabled by editing the file
    /etc/docker/daemon.json to contain:

     {
      "storage-driver":"aufs"
     }

    ... and re-starting any docker services on the host machine.

SEE ALSO
    *   The "dstar/doc/README.txt"
        <https://kaskade.dwds.de/dstar/doc/README.html> and the references
        mentioned therein describe the D* framework in more detail. Most of
        the D* documentation available under D* README
        <https://kaskade.dwds.de/dstar/doc/> predates the existence of
        "dstar-gantry" and of the "dstar-buildhost" image itself, and in the
        context of "dstar-gantry" should be interpreted relative to the
        running "dstar-buildhost" container.

    *   "dstar/doc/README_sources.txt"
        <https://kaskade.dwds.de/dstar/doc/README_sources.html> contains
        details on corpus source TEI-XML conventions.

    *   "dstar/doc/README_ssh.txt"
        <https://kaskade.dwds.de/dstar/doc/README_ssh.html> may provide some
        help setting up a new ssh identity. Note that "dstar-gantry"
        requires an accessible "ssh-agent", so if you want to run
        "dstar-gantry" on your local workstation or some other
        non-production host, you may need to run ssh-agent manually
        <https://kaskade.dwds.de/dstar/doc/README_ssh.html#Manual-ssh-agent-
        daemon>.

    *   "dstar/doc/Changes.txt"
        <https://kaskade.dwds.de/dstar/doc/Changes.html> contains a manual
        log of D*-related changes.

    *   See the "docker-run" <https://docs.docker.com/engine/reference/run/>
        manpage for details on docker options.

AUTHOR
    Bryan Jurish <jurish@bbaw.de> created the ddc-dstar corpus
    administration system and the "dstar-gantry" wrappers.

