NAME
    dstar-gantry - convenience wrapper for container-based dstar corpus
    operations

SYNOPSIS
     dstar-gantry.sh [GANTRY_OPTS] [GANTRY_ACTION(s)] [-- [DOCKER_OPTS] [-- [BUILD_ARGS]]]

     dstar-gantry.sh Options (GANTRY_OPTS):
       -h  , -help           # this help message
       -V  , -version        # show program version and exit
       -n  , -dry-run        # just print what we would do
       -fg , -batch , -bg    # run container in foreground (default), background, or non-interactively
       -rm , -persist        # remove container on termination (default) or don't
       -a  , -no-agent       # run without an ssh-agent connection (not recommended)
       -c CORPUS             # dstar corpus label (required for most operations)
       -d DSTAR_ROOT         # host path for sparse persistent dstar superstructure (default=$HOME/dstar)
       -C CORPUS_ROOT        # host path for dstar corpus checkout (default=DSTAR_ROOT/corpora/CORPUS)
       -S CORPUS_SRC         # host path of dstar corpus sources (default=DSTAR_ROOT/sources/CORPUS/ if present)
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
       sync-host             # syncronize local DSTAR_ROOT checkout via `svn update`
       sync-self             # syncronize local DSTAR_ROOT checkout via `svn update`
       sync                  # alias for 'sync-host' and 'sync-self'
       pull                  # retrieve selected IMAGE from docker registry (may require `docker login`)
       gc                    # clean up stale local dstar-buildhost docker images
       ...                   # other actions are passed to container docker/build script (see below)

     Docker Options (DOCKER_OPTS): see docker-run(1).

     Container docker/build Arguments (BUILD_ARGS; see also `dstar-gantry.sh help`):
       help                  # show help for container docker/build script
       self-test             # run rudimentary self-test(s)
       checkout              # checkout corpus build superstructure to CORPUS_ROOT/build/
       build                 # index a corpus in CORPUS_ROOT/build from sources in CORPUS_SRC/
       update                # update an existing index in CORPUS_ROOT/build/ from CORPUS_SRC/
       update-meta           # update index metadata in in CORPUS_ROOT/build/ from CORPUS_SRC/
       test                  # test a corpus build in CORPUS_ROOT/build/
       archive-build         # archive CORPUS_ROOT/build/ to ${dstar_archive_dir}
       archive-publish       # archive publishable corpus data to ${dstar_archive_dir}
       install               # install CORPUS_ROOT/build/ to CORPUS_ROOT/{server,web}/
       uninstall             # recursively delete CORPUS_ROOT/{server,web}/
       publish               # deploy CORPUS_ROOT/build/ to production host(s)
       run                   # run CORPUS_ROOT/{server,web}/ corpus instance in container
       shell                 # run a bash shell in the container
       exec CMD...           # execute an arbitrary CMD... in container

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
    host roles
    <https://kaskade.dwds.de/dstar/doc/README.html#Hosts-and-Roles>, but is
    mostly intended to act as a (virtual) "BUILDHOST"
    <https://kaskade.dwds.de/dstar/doc/README.html#BUILDHOST>.

    The remainder of this document describes the "dstar-gantry.sh" wrapper
    script in more detail; it does not constitute exhaustive documentation
    for the dstar corpus management framework or its features and
    functionality, not even of that subset of the dstar functionality which
    can be invoked through "dstar-gantry.sh". Please consult the relevant
    dstar documentation <https://kaskade.dwds.de/dstar/doc/> if you have
    questions which aren't addressed by this document.

    See "INSTALLATION" for instructions on installing "dstar-gantry" on your
    local machine, see "USAGE" for details on the various options and
    arguments, and see "EXAMPLES" for some example "dstar-gantry.sh"
    invocations.

INSTALLATION
    This section describes the installation procedure for debian-based linux
    machines. "dstar-gantry" was developed and tested on an x86_64 machine
    running Debian GNU/Linux 10 ("buster"). Other systems and architectures
    may work too, but are not explicitly supported.

    If you are running "dstar-gantry.sh" on a "semi-production" host (e.g.
    lal.dwds.de), you can skip to "initialize persistent data".

  Requirements
    debian packages
        "dstar-gantry.sh" requires the debian packages: "bash",
        "openssh-client", and "subversion" to be installed on the host
        system:

         $ sudo apt-get update && sudo apt-get install bash openssh-client subversion

    docker
        You will need docker <https://docs.docker.com/get-docker/> installed
        on your local machine with an appropriate docker storage driver, and
        the requisite permissions
        <https://docs.docker.com/engine/install/linux-postinstall/> for your
        local user account (e.g. membership in the "docker" group).
        "dstar-gantry" was developed and tested using the "docker-ce" and
        "docker-ce-client" packages version 19.03.8. See
        "https://docs.docker.com/get-docker/"
        <https://docs.docker.com/get-docker/> for instructions on how to
        install docker.

    registry credentials
        If you wish to make use of gantry's "pull" action to acquire the
        latest "dstar-buildhost" docker image (recommended), you will need
        credentials (username and password) for the ZDL docker registry, and
        will need to manually log into the registry using "docker login"
        <https://docs.docker.com/engine/reference/commandline/login/>:

         $ docker login https://lex.dwds.de:443
         Username: ZDL_DOCKER_REGISTRY_USERNAME
         Password: ZDL_DOCKER_REGISTRY_PASSWORD
         Login Succeeded

        Contact the "dstar-gantry" maintainer or the ZDL docker registry
        maintainer (currently Gregor Middell) if you do not have credentials
        for the ZDL docker registry.

    ssh-agent
        You will need an accessible ssh-agent
        <https://en.wikipedia.org/wiki/Ssh-agent> for your local user
        account as indicated by the "SSH_AUTH_SOCK" environment variable,
        with at least one registered identity (public+private key-pair).

        In order to avoid password prompts during sparse subversion
        checkouts on the local host (recommended), your ssh identity should
        be authorized for password-free access to "svn.dwds.de", as whatever
        user your "~/.ssh/config" <https://linux.die.net/man/5/ssh_config>
        specifies (by default the same username as on your local machine).

        In order to avoid password prompts during implicit subversion
        operations in the "dstar-buildhost" container invoked by gantry
        (recommended), your ssh identity should be authorized for
        password-free access to "ddc@svn.dwds.de".

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

         $ svn checkout svn+ssh://svn.dwds.de/home/svn/dev/ddc-dstar/docker/gantry/trunk ~/dstar-gantry

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
        Initialize persistent sparse local dstar checkout (usually in
        "$HOME/dstar") with the "init" action:

         $ dstar-gantry.sh init

        Example output (trimmed):

         dstar-gantry.sh: INFO: init: (re-)initializing sparse persistent DSTAR_ROOT=/home/USER/dstar
         dstar-gantry.sh: CMD: svn co --depth=files svn+ssh://svn.dwds.de/home/svn/dev/ddc-dstar/trunk /home/USER/dstar
         A    /home/USER/dstar/.DSTAR_ROOT
         ...
         dstar-gantry.sh: INFO: no container actions BUILD_ARG(s) specified: nothing to do.

        NOTE: if you are running "dstar-gantry.sh" on a "semi-production"
        host (e.g. lal.dwds.de), you should probably be using the central
        dstar checkout in "/home/ddc-dstar/dstar/" rather than a "private"
        gantry checkout in "$HOME/dstar/" ... in this case, the gantry
        maintainer has probably already installed an appropriate
        machine-wide "/etc/dstar-gantry.rc", and you may want to create a
        convenience symlink in you home directory to remind you:

         $ ln -sfT /home/ddc-dstar/dstar ~/dstar

    retrieve docker image
        Download the latest "dstar-buildhost" image from the ZDL docker
        registry with the "pull" action:

         $ dstar-gantry.sh pull

        Example output (trimmed):

         dstar-gantry.sh: CMD: docker pull lex.dwds.de:443/dstar/dstar-buildhost:latest
         latest: Pulling from dstar/dstar-buildhost
 
         Digest: sha256:e5b47f225619e6b433df0dbcdcdfdfdb93e703893ceb6ed9f78f338e77358a77
         Status: Downloaded newer image for lex.dwds.de:443/dstar/dstar-buildhost:latest
         lex.dwds.de:443/dstar/dstar-buildhost:latest
         dstar-gantry.sh: INFO: no container actions BUILD_ARG(s) specified: nothing to do.

    run self-test
        Run rudimentary self-tests with the gantry "self-test" action:

         $ dstar-gantry.sh self-test

        Example output (trimmed):

         dstar-gantry.sh: INFO: using DSTAR_ROOT=/home/USER/dstar
         dstar-gantry.sh: WARNING: neither CORPUS nor CORPUS_ROOT specified (use the -c or -C options)
         dstar-gantry.sh: WARNING: no CORPUS_SRC directory specified (expect trouble if you're trying to (re-)index a corpus)
         dstar-gantry.sh: INFO: setting RESOURCE_DIR=/local/home/ddc-dstar/dstar/resources
         dstar-gantry.sh: WARNING: CORPUS_ROOT= does not exist (continuing anyway, YMMV)
         dstar-gantry.sh: CMD: docker run --rm -ti --name=dstar-gantry- ... self-test
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
        <https://docs.docker.com/engine/reference/run/> subprocess for the
        embedded "dstar-buildhost" container.

    BUILD_ARGS
        "BUILD_ARGS" are passed to the "/dstar/docker/build" script
        invocation in the embedded "dstar-buildhost" container.

  Gantry Options
    -h, -help
        Display a brief help message.

    -V, -version
        Display the version information for "dstar-gantry" itself.

    -n, -dry-run
        If specified, just prints what would have been done, but doesn't
        perform any destructive actions.

    -fg, -batch, -bg
        Specifies whether to run the embedded "dstar-buildhost" container
        interactively in the foreground ("-fg", default), non-interactively
        ("-batch"), or detached in the background ("-bg"). Foreground
        ("-fg") operation is equivalent to the "docker-run" "--tty=true" and
        "--interactive=true" options, batch ("-batch") operation is
        equivalent to the "docker-run" "--tty=false" and
        "--interactive=false" options, and background ("-bg") operation is
        equivalent to the "docker-run" "--detached=true" option. See
        docker-run(1)
        <https://docs.docker.com/engine/reference/run/#options> for details.

        If you choose to run the container in the background (e.g. for
        "build" operations on large corpora), you can still view the default
        console ouptut with the "docker logs"
        <https://docs.docker.com/engine/reference/commandline/logs/>
        command, or inspect the build logs in "CORPUS_ROOT/build/log/"
        directly.

    -rm, -persist
        Specifies whether ("-rm") or not ("-persist") to remove the embedded
        "dstar-buildhost" container when the requested build operation(s)
        have completed. This behavior is implemented in terms of the
        "docker-run" "--rm" option; see docker-run(1)
        <https://docs.docker.com/engine/reference/run/#options> for details.
        If you request container persistence with the "-persist" option (or
        the lower-level docker option "--rm=false"), you will have to remove
        it yourself with the "docker rm"
        <https://docs.docker.com/engine/reference/commandline/rm/> command.

    -a, -no-agent
        Specifying this option will allow "dstar-gantry.sh" to invoke a
        subordinate "dstar-buildhost" container even if it does not detect a
        running "ssh-agent", and will bypass any running agent by unsetting
        the "SSH_AUTH_SOCK" environment variable for the host
        "dstar-gantry.sh" process itself. This can be useful if you're
        performing only container-local operations which don't require
        external authentication (e.g. "run" with
        "dstar_checkout_corpus_opts=-dummy"). Without this option,
        "dstar-gantry.sh" will issue an error message and exit with abnormal
        status unless it detects a running "ssh-agent" with at least one
        registered identity, which is usually The Right Thing To Do (TM).

    -c CORPUS
        Specifies the dstar corpus label ("collection label") for the
        operand corpus. Required for most operations.

    -d DSTAR_ROOT
        Specifies the host path (or symlink) used for (sparse) persistent
        dstar superstructure (default="$HOME/dstar"). By default, persistent
        CAB resources and index data will be created here. This directory
        should be a sparse checkout of the dstar project
        <https://kaskade.dwds.de/dstar/doc/README.html#Project-Directory-Str
        ucture> containing at least partial checkouts of the "doc/"
        <https://kaskade.dwds.de/dstar/doc/README.html#doc>, "corpora/"
        <https://kaskade.dwds.de/dstar/doc/README.html#corpora>, "sources/"
        <https://kaskade.dwds.de/dstar/doc/README.html#sources>, and
        "resources/"
        <https://kaskade.dwds.de/dstar/doc/README.html#resources>
        subdirectories.

        On "semi-production" dstar hosts (e.g. "lal.dwds.de"), you should
        typically use a global "DSTAR_ROOT" checkout in
        "/home/ddc-dstar/dstar".

    -C CORPUS_ROOT
        Specifies the host path (or symlink) used for dstar corpus checkout
        (default="DSTAR_ROOT/corpora/CORPUS"). Implies volume mount "-v
        CORPUS_ROOT:/dstar/corpora/CORPUS".

    -S CORPUS_SRC
        Specifies the host path (or symlink) where dstar corpus sources
        reside (default="DSTAR_ROOT/sources/CORPUS/" if present, otherwise
        `readlink -m CORPUS_ROOT/src` if present, otherwise required).
        Implies volume mount "-v CORPUS_SRC:/dstar/sources/CORPUS:ro".

    -R RESOURCES_DIR
        Specifies the host path (or symlink) for persistent CAB resources
        (default="DSTAR_ROOT/resources/" if present). Implies volume mount
        "-v RESOURCES_DIR:/dstar/resources".

    -RO If the "-RO" option is specified and "RESOURCES_DIR" is present on
        the local machine, then "RESOURCES_DIR" will be mounted read-only in
        the container, which suppresses resource synchronization in the
        running container. If you want each container invocation to ensure
        that its CAB resources are fully up-to-date, you should NOT use this
        option. It can be useful to bypass synchronization overhead,
        minimize network bandwidth, and ensure resource consistency for
        post-hoc updates of existing corpora though. Use with consideration.

    -f RCFILE
        Reads gantry configuration variables from "RCFILE" on the host
        machine. "RCFILE" is evaluated as bash source. May be specified more
        than once, in which case files are read in the order specified and
        later declarations may clobber earlier ones. By default,
        "dstar-gantry.sh" reads the following global configuration files (if
        they exist) before evaluating any "RCFILE" specified on the
        command-line:

         /etc/dstar-gantry.rc
         $HOME/.dstar-gantry.rc

        See the example "dstar-gantry.rc" file
        <http://svn.dwds.de/websvn/filedetails.php?repname=D%2A%3A+Dev-Repos
        itory&path=%2Fddc-dstar%2Fdocker%2Fgantry%2Ftrunk%2Fdstar-gantry.rc>
        in the "dstar-gantry" distribution for a list of available
        variables.

    -i IMAGE
        Specifies the docker image to be pulled and/or invoked via "docker
        run" <https://docs.docker.com/engine/reference/run/>. Default is
        "lex.dwds.de:443/dstar/dstar-buildhost:latest".

    -e VAR=VALUE
        Specify an environment variable override for the container via
        "docker run -e VAR=VALUE"
        <https://docs.docker.com/engine/reference/run/#env-environment-varia
        bles>.

    -E ENV_FILE
        Specify a file containing environment variable overrides for the
        container, via "docker run --env-file ENV_FILE"
        <https://docs.docker.com/engine/reference/run/#env-environment-varia
        bles>.

    -v /PATH:/MOUNT
        Mounts the host directory "/PATH" as a volume into the container at
        "/MOUNT", passed to "docker_run -v"
        <https://docs.docker.com/engine/reference/run/#volume-shared-filesys
        tems>.

        Potentially useful volume mounts "/MOUNT" include:

          /dstar/config/            # global dstar configuration (read-only)
          /dstar/resources/         # CAB analysis resources (read-only)

    -x CABX_RUN
        Select container-internal CAB server(s) to start for container run
        action; default="dstar-http-9096".

    -p HTTP_PORT
        Map containers port 80 to host port "HTTP_PORT" for "run" action via
        "docker run -p HTTP_PORT:80"
        <https://docs.docker.com/engine/reference/run/#expose-incoming-ports
        >.

    -u USER
        Specifies username or UID of host build user (default="ddc-admin" if
        present, otherwise current user). If the UID does not exist in the
        container (it probably doesn't), it will be created.

    -g GROUP
        Specifies group name or GID of host build user (default="ddc-admin"
        if present, otherwise current group). If the GID does not exist in
        the container (it probably doesn't), it will be created.

  Gantry Actions
   init
    (Re-)initializes persistent sparse local "DSTAR_ROOT" checkout on the
    local host (usually "$HOME/dstar"). You should only have to call this
    once per host, before performing any other "dstar-gantry.sh" actions.

   sync-host
    Synchronizes the persistent sparse local "DSTAR_ROOT" checkout on the
    local host (usually "$HOME/dstar") via "svn update". You should
    typically call this before each "dstar-gantry.sh" session, in order to
    ensure that your "DSTAR_ROOT" checkout is up-to-date.

   sync-self
    Attempts to synchronize the local "dstar-gantry" checkout via "svn
    update". If the "dstar-gantry.sh" script (or symlink) does not resolve
    to an SVN working copy on your system, this won't work, and you will
    need to perform any updates manually. You should typically call this
    before each "dstar-gantry.sh" operation, in order to ensure that your
    "dstar-gantry.sh" itself is up-to-date.

   sync
    Convenience alias for the "sync-host" and "sync-self" actions.

   pull
    Retrieves the selected "dstar-buildhost" IMAGE from the ZDL docker
    registry. May require a preceding "docker login".

   gc
    Cleans up stale "dstar-buildhost" docker images on the local host.

   BUILD_ACTION...
    Other non-option arguments (not beginning with a dash "-") are passed
    verbatim as "Container Actions" to the "/dstar/docker/build" script in
    the embedded "dstar-buildhost" container.

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
    call in the embedded "dstar-buildhost" container. See the output of
    "dstar-gantry.sh help" for a synopsis of the "/dstar/docker/build"
    calling conventions.

    help
        Shows a brief help message from the container "/dstar/docker/build"
        script.

    self-test
        Runs some rudimentary self-test(s) and reports results. Not all
        self-tests need to pass in order for "dstar-gantry.sh" to be useful;
        the functionality you need depends on what you're trying to do and
        your personal preferences.

    checkout
        Creates or updates corpus build superstructure in
        "CORPUS_ROOT/build/" from SVN. This is basically a wrapper for
        "dstar-checkout-corpus.sh"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Checkout>, i.e.
        a corpus checkout
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Checkout>. You
        should probably never have to invoke this action manually, since it
        is implicitly called by the higher-level corpus operations such as
        "build", "update", "publish", etc.

    build
        (Re-)indexes a corpus in "CORPUS_ROOT/build/" from TEI-XML sources
        in "CORPUS_SRC/". This is basically a wrapper for
        "dstar-checkout-corpus.sh"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Checkout> and
        "CORPUS_ROOT/build/build.sh -build"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#build.sh-and-cron-auto
        build.sh>, i.e. a full corpus re-build
        <https://kaskade.dwds.de/dstar/doc/talks/corpus-ops-2019/#howto-buil
        d>.

    update
        Updates an existing corpus index in "CORPUS_ROOT/build/" from
        TEI-XML sources in "CORPUS_SRC/". This is basically a wrapper for
        "dstar-checkout-corpus.sh"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Checkout> and
        "CORPUS_ROOT/build/build.sh -update"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#build.sh-and-cron-auto
        build.sh>, i.e. an incremental corpus update
        <https://kaskade.dwds.de/dstar/doc/README_build.html#Incremental-Upd
        ate> as described here
        <https://kaskade.dwds.de/dstar/doc/talks/corpus-ops-2019/#howto-upda
        te>.

    update-meta
        Updates metadata for an existing corpus index in "CORPUS_ROOT/build"
        from TEI-XML sources in "CORPUS_SRC/". This is basically a wrapper
        for "dstar-checkout-corpus.sh"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Checkout> and
        "CORPUS_ROOT/build/build.sh -update-meta"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#build.sh-and-cron-auto
        build.sh>, i.e. a corpus metadata update
        <https://kaskade.dwds.de/dstar/doc/README_build.html#Metadata-Update
        >.

    test
        Runs automated consistency tests for an existing corpus build in
        "CORPUS_ROOT/build/test/". This is basically a wrapper for
        "dstar-checkout-corpus.sh"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Checkout> and
        "CORPUS_ROOT/build/build.sh -test"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#build.sh-and-cron-auto
        build.sh>, i.e. corpus consistency tests
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Consistency-Testing>.

    archive-build
        Archives an existing corpus build-directory "CORPUS_ROOT/build/" to
        the directory "${dstar_archive_dir}" if set, otherwise to the
        (corpus-specific) directory specified by the "ARC_BUILD_DIR" dstar
        make variable; usually "CORPUS_ROOT/archive/". The build-archive
        will be created as a gzipped tar archive
        "CORPUS.build-*DATETIME*.tar.gz" where *DATETIME* is a timestamp in
        *YYYY-MM-DD.HHMMSS* format, and will include all intermediate build
        files in "CORPUS_ROOT/build/".

    archive-publish
        Archives publishable corpus data from the corpus build directory
        "CORPUS_ROOT/build/" to the directory "${dstar_archive_dir}" if set,
        otherwise to the (corpus-specific) directory specified by the
        "ARC_PUBLISH_DIR" dstar make variable; usually
        "CORPUS_ROOT/archive/". The publish-archive will be created as a
        gzipped tar archive "CORPUS.publish-*DATETIME*.tar.gz" where
        *DATETIME* is a timestamp in *YYYY-MM-DD.HHMMSS* format, and should
        contain all the index data required for a production runtime corpus
        instance on "RUNHOST" and/or "WEBHOST"
        <https://kaskade.dwds.de/dstar/doc/README.html#Hosts-and-Roles>).
        Future versions of this software may support additional operations
        on such archives.

        Note that archives created with the "archive-publish" action only
        include that subset of the data from local corpus build directory
        "CORPUS_ROOT/build/" which would be deployed by a "publish"
        operation, and not the actual published index data from remote
        runtime "production" host(s) as specified by the "PUBLISH_DEST"
        and/or "WEB_PUBLISH_DEST" dstar make variables. Archives created
        with the "archive-publish" action will also not include any
        intermediate build files, so it should be much smaller in size than
        those created by the "archive-build" action. Unlike an
        "archive-build" archive however, an "archive-publish" archive cannot
        be used as the basis for subsequent subsequent incremental corpus
        updates
        <https://kaskade.dwds.de/dstar/doc/README_build.html#Incremental-Upd
        ate> or infrastructure maintainence; please act responsibly.

    install
        Installs an existing corpus index from "CORPUS_ROOT/build/" to
        "CORPUS_ROOT/{server,web}/" within the running "dstar-buildhost"
        container, usually in preparation for local staging. See also
        "uninstall".

    uninstall
        Recursively removes corpus runtime data directories
        "CORPUS_ROOT/{server,web}/", recommended after local staging. This
        action will remove everything under "CORPUS_ROOT/{server,web}/", so
        if you've stored anything there yourself, you should save it before
        executing this action.

    publish
        Deploy an existing corpus index from "CORPUS_ROOT/build/" to
        production host(s) as selected by the dstar make variables
        "PUBLISH_DEST" and/or "WEB_PUBLISH_DEST".

    run Runs a "CORPUS" instance from "CORPUS_ROOT/{server,web}/" in the
        temporary container. For this action, you will probably also want to
        specify "-p HTTP_PORT". If specified, this must be the last
        container action executed.

        You can inspect the console log for the embedded container with the
        "docker logs"
        <https://docs.docker.com/engine/reference/commandline/logs/>
        command.

    shell
        Runs a "bash" shell as the build user in the embedded container;
        useful for inspection and debugging.

    exec CMD
        Just executes "CMD..." in the embedded container. If specified, this
        must be the final container action executed. Use with extreme
        caution.

  Container Environment Variables
    The following environment variables influence operations in the embedded
    "dstar-buildhost" container, and can be customized by means of the
    gantry "-e VAR=VALUE" and/or "-E ENV_FILE" options.

    SSH_AUTH_SOCK
        The communication socket for ssh-agent on the docker host will be
        bind-mounted into the container as "/tmp/ssh-auth-gantry.sock". The
        embedded "/dstar/docker/build" script will typically take care of
        wrapping that socket as "/tmp/ssh-agent-wrap.sock", to ensure
        appropriate permissions for the build USER and GROUP within the
        container itself. See the "-no-agent" if you really need to run
        gantry without an accessible ssh-agent.

    dstar_init_hooks
        Default initialization hook directory for the embedded
        "/dstar/docker/build" script; typically empty. If you need to
        perform additional actions on the container startup, you can set
        this variable to the container path of a (mounted) directory
        containing hooks appropriate for the "run-parts"
        <https://manpages.debian.org/buster/debianutils/run-parts.8.en.html>
        system utility. If no INIT_HOOK_DIR(s) are specified on the
        command-line or by this environment variable, hooks are run from any
        directory matching

         /home/ddc-dstar/dstar/docker/build.d/
         /opt/dstar-build*/

    dstar_build_uid
        Numeric UID of build user; should be automatically populated by
        gantry from the "-u USER" option. If no user with this UID exists in
        the container (likely), a temporary user "dstar-build" will be
        created during container startup.

    dstar_build_gid
        Numeric GID of build group; should be automatically populated by
        gantry from the "-g GROUP" option. If no group with this GID exists
        in the container (likely), a temporary group "dstar-build" will be
        created during container startup and the "dstar_build_uid" user
        approrpriately modified.

    dstar_build_umask
        Specifies the permissions umask for the build process. The default
        is typically specified in the "dstar-buildhost" docker image itself
        as 002, which creates new files with the group-writable flag set. If
        you're feeling paranoid, you can set this to 022 or even 077, but
        that may cause problems down the line.

    dstar_corpora
        Specifies the corpus or corpora to operate on as a
        whitespace-separated list. Typcically set by "dstar-gantry.sh"
        itself to "CORPUS". You probably don't want to set this yourself.

    dstar_corpus
        Alias for "dstar_corpora".

    dstar_archive_dir
        Target directory for "archive-build" and "archive-publish" actions.
        Empty (unset) by default.

    dstar_sync_resources
        Whether or not to synchronize CAB resources to "RESOURCES_DIR" on
        container startup. Accepts values "auto" (default), "no", and
        "force". The default value ("auto") will only attempt to synchronize
        resources if "RESOURCES_DIR" is not mounted read-only.

    dstar_sync_rcfiles
        Specifies which CAB resources in "RESOURCES_DIR" are to by
        synchronized on container startup. If set and non-empty, overrides
        that value of the dstar make variable "CABRC_FILES" for the implicit
        "make -C /dstar/resources sync" syncronization call. Empty by
        default, which uses the default value for "CABRC_FILES", and should
        cause all default CAB resources to be synchronized.

    dstar_checkout_corpus_opts
        Specifies options for "dstar-checkout-corpus.sh"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Checkout> as
        implicitly called prior to any corpus operation. Default: "-force
        -local-config".

    dstar_build_sh_opts
        Specifies options for "CORPUS_ROOT/build/build.sh -build"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#build.sh-and-cron-auto
        build.sh>. Default: "-echo-preset=make-info".

    dstar_cabx_run
        Specifies which CAB server(s) to start in the container for the
        "run" action as a whitespace-separated list. CAB server(s) are
        identified by the file basename up to the first dot (".") of the
        corresponding configuration file "/dstar/cabx/*.rc". Default:
        "dstar-http-9096". Known values:

         dstar-http-9096       - runtime expansion for synchronic German
         dstar-http-dta-8088   - runtime expansion for historical German
         dstar-http-dta-9099   - "public" web-service for historical German
         dstar-http-en-9097    - runtime expansion for synchronic English
         dstar-http-taghx-9098 - runtime lemma-equivalence using TAGH

    dstar_relay_conf
        Specifies container path containing "socat"
        <https://linux.die.net/man/1/socat> relay configuration for
        "/dstar/init/dstar-relay.sh". Empty by default, which starts no
        relays. This option is useful for workstations with insufficient
        resources to run embedded CAB expansion servers locally, or in
        situations where "RESOURCES_DIR" is not fully populated in order to
        bind "virtual" local ports which forward all requests to a remote
        server daemon (e.g. "data.dwds.de:9096" for the CAB expansion server
        "dstar-http-9096"). It can also be useful for testing "metacorpora"
        in a container without having to run all daughter corpora in the
        container as well; in this case, relays should be defined for each
        immediate daughter node of the metacorpus to be run.

        See "dstar-buildhost:/dstar/init/etc_default_dstar_relay"
        <http://svn.dwds.de/websvn/filedetails.php?repname=D%2A%3A+Dev-Repos
        itory&path=%2Fddc-dstar%2Ftrunk%2Finit%2Fetc_default_dstar_relay>
        for syntax and more details.

    VAR All environment variables are passed down to child processes (e.g.
        "dstar-nice.sh"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#dstar-nice-sh>,
        "make"); see "Customizable Variables" in "README_build.txt"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#Customizable-Va
        riables> for more (non-exhaustive) details.

EXAMPLES
    This section provides rudimentary sketches of some typical dstar corpus
    operations using "dstar-gantry.sh". Since "dstar-gantry" is basically
    just a convenience wrapper around the "ddc-dstar" corpus infrastructure,
    most of the existing dstar documentation
    <https://kaskade.dwds.de/dstar/doc/> applies to "dstar-gantry" as well,
    where the "DSTAR_BUILDHOST"
    <https://kaskade.dwds.de/dstar/doc/README.html#BUILDHOST> role is
    fulfilled by the embedded embedded "dstar-buildhost" IMAGE container,
    and the corpus directories "CORPUS_ROOT" and "CORPUS_SRC" are
    bind-mounted into the container from the gantry host itself.

    The examples in this section assume you have a working "dstar-gantry"
    installation in your $PATH and a sparse local "DSTAR_ROOT" directory or
    symlink at "$HOME/dstar". See "INSTALLATION" if that is not the case.

    Corpus-specific examples assume you are working on a corpus called
    ""MYCORPUS""; replace ""MYCORPUS"" with the name of your real corpus
    where appropriate.

  Common Prerequisites
    In addition to a working gantry installation, you should typically do
    the following performing any corpus operation:

    Pull and Synchronize
         $ dstar-gantry.sh pull sync

        Ensure your host's "DSTAR_ROOT", gantry installation, and
        "dstar-buildhost" image are up-to-date with the "sync" and "pull"
        actions.

    Setup Corpus Sources
         $ ln -s /path/to/real/MYCORPUS/tei-xml/sources ~/dstar/sources/MYCORPUS

        You presumably have some TEI-XML corpus sources on which you wish to
        operate; these should follow the guidelines in
        "dstar/doc/README_sources"
        <https://kaskade.dwds.de/dstar/doc/README_sources.html>. If you want
        to avoid having to specify the gantry "-S CORPUS_SRC" option for
        every "dstar-gantry.sh" call, you should symlink the location of the
        "real" sources into your "DSTAR_ROOT" checkout at
        "DSTAR_ROOT/sources/MYCORPUS". See also "Corpus Sources" in the
        dstar-HOWTO
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Sources> and
        README_sources.txt
        <https://kaskade.dwds.de/dstar/doc/README_sources.html>.

    Setup Corpus Configuration
        You will need provide a configuration ("MYCORPUS.mak" and
        "MYCORPUS.opt") for your corpus as described under "Corpus
        Configuration" in the dstar-HOWTO
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Configuration>
        and under "HOWTO: Corpus Configuration" in the dstar corpus
        operations slides
        <https://kaskade.dwds.de/dstar/doc/talks/corpus-ops-2019/#howto-conf
        ig>. Since the default "DSTAR_CONFIG"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#DSTAR_CONFIG>
        for dstar-gantry builds resides by default in the embedded
        "dstar-buildhost" container, you may want to provide the corpus
        configuration by creating a "CORPUS_ROOT/config.local/"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#Corpus-specific
        -customizations-with-config.local> directory; otherwise you will
        have to commit the corpus configuration files to SVN under
        "DSTAR_ROOT/config/"
        <https://kaskade.dwds.de/dstar/doc/README.html#config> before
        proceeding. It should be safe to use gantry's sparse DSTAR_ROOT for
        this purpose, but note that you will first have to check it out
        (gantry doesn't require or checkout "DSTAR_ROOT/config/" by
        default):

         $ svn update --set-depth=infinity ~/dstar/config
         $ emacs \
            ~/dstar/config/corpus/MYCORPUS.mak \
            ~/dstar/config/opt/MYCORPUS.opt \
            ~/dstar/doc/Changes.txt
         $ svn add ~/dstar/config/*/MYCORPUS.*
         $ svn commit -m "+ added and/or updated corpus configuration for MYCORPUS" \
            ~/dstar/config/*/MYCORPUS.* \
            ~/dstar/doc/Changes.txt

        If you choose to use a global configuration in your sparse
        "DSTAR_ROOT/config/", you will probably want to mount it as a volume
        in the embedded container by specifying ""-v
        $DSTAR_ROOT/config:/dstar/config:ro"" on the gantry command-line.

  Example: Corpus Build
    Before attempting to (re-)build a corpus, you should ensure that you
    have fulfilled all the "Common Prerequisites".

    MYCORPUS build
         $ dstar-gantry.sh -bg -c MYCORPUS build

        Building a corpus index from TEI-XML sources or re-building an
        existing corpus index with the gantry "build" action follows the
        basic pattern described under "Annotate and Build" in the
        dstar-HOWTO
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Annotate-and-Build>
        using "dstar-checkout-corpus.sh"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#dstar-checkout-corpus.
        sh> to populate or update the "CORPUS_ROOT" checkout and calling
        "/dstar/corpora/MYCORPUS/build.sh -build"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#build.sh> in the in
        the embedded "dstar-buildhost" container. By default, full
        build-logs
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Build-Logging> will be
        written to "CORPUS_ROOT/build/log/build.*DATETIME*.log", and some
        progress information will be printed to the console via "cronit.perl
        -echo-preset=make-info"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#cronit.perl>. See
        README_build <https://kaskade.dwds.de/dstar/doc/README_build.html>
        for more details on the build process.

    MYCORPUS consistency testing
         $ dstar-gantry.sh -RO -c MYCORPUS test

        Once a corpus index has been succesfully built, you can run some
        basic consistency checks with the gantry test action; see
        "Consistency Testing" in the dstar-HOWTO
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Consistency-Tests> for
        more information. By default, full test-logs
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Build-Logging> will be
        written to "CORPUS_ROOT/build/log/test.*DATETIME*.log", and some
        progress information will be printed to the console.

    MYCORPUS staging
         $ dstar-gantry.sh -bg -p 8001 -RO -c MYCORPUS install run
         $ sensible-browser http://localhost:8001/dstar/MYCORPUS
         ... do some manual testing ...
         $ docker kill dstar-gantry-MYCORPUS
         $ dstar-gantry.sh -RO -c MYCORPUS uninstall

        Once a corpus index has been succesfully built, you can use
        "dstar-gantry.sh" to install and run a staging" instance of the
        dstar "RUNHOST" and "WEBHOST" roles
        <https://kaskade.dwds.de/dstar/doc/README.html#Hosts-and-Roles> for
        that corpus in the embedded "dstar-buildhost" container, analogous
        to (but independent of) the "Sandbox Testing"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Sandbox-Testing>
        functionality for "bare-metal" dstar corpus builds. You only need to
        "install" if you have updated corpus index data in the
        "CORPUS_ROOT/build/" directory, e.g. via the "build", "update", or
        "update-meta" operations); you can re-stage an existing installation
        with the gantry "run" action.

        Use the gantry -p HTTP_PORT option to specify a host port number to
        map to the embedded HTTP server, and use the gantry "-bg" or "docker
        run -d" <https://docs.docker.com/engine/reference/run/#detached--d>
        option to run the embedded container in the background. When you are
        done with manual testing, remember to terminate the running
        container with "docker kill"
        <https://docs.docker.com/engine/reference/commandline/kill/> It is
        also good practice to "uninstall" the runtime data when you are done
        with the staging instance.

        If you are running dstar-gantry on a "GANTRYHOST"
        <https://kaskade.dwds.de/dstar/doc/README.html#GANTRYHOST> behind a
        firewall and you wish to call your browser on a different machine
        (let's call it "WORKSTATION"), you may need to setup an ssh tunnel
        <https://www.ssh.com/ssh/tunneling/example> to the remote port, and
        shut it down again when you're finished with the staging instance.
        This can be accomplished by e.g.:

         GANTRYHOST  $ dstar-gantry.sh -RO -bg -p 8001 -c MYCORPUS install run
         WORKSTATION $ ssh 8002:GANTRYHOST:8001 -N GANTRYHOST & gantry_tunnel_pid=$!
         WORKSTATION $ sensible-browser http://localhost:8002/dstar/MYCORPUS

         ... do some manual testing & inspection in your browser ...

         WORKSTATION $ kill $gantry_tunnel_pid
         GANTRYHOST  $ docker kill dstar-gantry-MYCORPUS
         GANTRYHOST  $ dstar-gantry.sh -RO -c MYCORPUS uninstall

        ... replace 8001 in the above example with an "HTTP_PORT" of your
        choice to be bound by the container on "GANTRYHOST", and replace
        8002 with a port number of your choice to be bound by the ssh-tunnel
        on "WORKSTATION".

    MYCORPUS deployment
         $ dstar-gantry.sh -RO -c MYCORPUS publish

        If the corpus build is satisfactory, the next step is usually to
        install the newly indexed corpus onto the production "RUNHOST" and
        "WEBHOST"
        <https://kaskade.dwds.de/dstar/doc/README.html#Hosts-and-Roles>. The
        "dstar-gantry" ""publish"" action follows the pattern described
        under "Install or Publish" in the dstar-HOWTO
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Install-or-Publish>,
        using "dstar-checkout-corpus.sh"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#dstar-checkout-corpus.
        sh> to populate and/or update the runtime checkous
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Runtime-Checkouts> by
        calling "CORPUS_ROOT/build/build.sh -publish"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#build.sh-and-cron-auto
        build.sh> in the embedded "dstar-buildhost" container. By default,
        full publish-logs
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Build-Logging> will be
        written to "CORPUS_ROOT/build/log/publish.*DATETIME*.log", and some
        progress information will be printed to the console.

    MYCORPUS post-deployment
        If the deployment is successful, continue with the procedures
        described under "It's Alive"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Its-Alive>, "Nail it
        Down" <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Nail-it-Down>,
        and (optionally) "Housekeeping"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Housekeeping> in the
        dstar-HOWTO <https://kaskade.dwds.de/dstar/doc/HOWTO.html>. In
        particular, if you have deployed a "production" corpus which was
        configured by means of a "CORPUS_ROOT/config.local/"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#Corpus-specific
        -customizations-with-config.local> directory, you should ensure that
        the Corpus configuration file(s)
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Configuration>
        from "CORPUS_ROOT/config.local/" are checked into the central
        "ddc-dstar/trunk/config"
        <https://kaskade.dwds.de/dstar/doc/README.html#config> repository,
        and document your changes in "DSTAR_ROOT/doc/Changes.txt"
        <https://kaskade.dwds.de/dstar/doc/Changes.html>.

  Example: Corpus Update
    Before attempting to update a corpus, you should ensure that you have
    fulfilled all the "Common Prerequisites", and that you have an
    up-to-date instance of the "CORPUS_ROOT" checkout -- including any
    intermediate build data -- on the gantry host, typically under
    "DSTAR_ROOT/corpora/MYCORPUS".

    MYCORPUS update
         $ dstar-gantry.sh -bg -c MYCORPUS update

        Updating an existing corpus index after some source file(s) have
        been changed, added, and/or deleted by means of the gantry update
        action follows the basic pattern described under "Incremental
        Update" in "README_build.txt"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#Incremental-Upd
        ate>. The gantry update action uses uses "dstar-checkout-corpus.sh"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#dstar-checkout-corpus.
        sh> to update the existing "CORPUS_ROOT" superstructure, and calls
        "CORPUS_ROOT/build/build.sh -update"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#build.sh> in the in
        the embedded "dstar-buildhost" container to perform the index
        update. By default, full build-logs
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Build-Logging> will be
        written to "CORPUS_ROOT/build/log/update.*DATETIME*.log", and some
        progress information will be printed to the console via "cronit.perl
        -echo-preset=make-info"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#cronit.perl>. See
        "Incremental Update" in "README_build.txt"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#Incremental-Upd
        ate> for more details.

    MYCORPUS post-update
        After updating a corpus with the update action, proceed as you would
        after a build action, i.e. with consistency testing, staging,
        deployment, and post-deployment.

  Example: Corpus Metadata Update
    Before attempting to update corpus metadata, you should ensure that you
    have fulfilled all the "Common Prerequisites", and that you have an
    up-to-date instance of the "CORPUS_ROOT" checkout -- including any
    intermediate build data -- on the gantry host, typically under
    "DSTAR_ROOT/corpora/MYCORPUS".

    MYCORPUS metadata-update
         $ dstar-gantry.sh -RO -bg -c MYCORPUS update-meta

        Updating metadata for an existing corpus index after some source
        file(s) have been changed, added, and/or deleted by means of the
        gantry update-meta action follows the basic pattern described under
        "Metadata Update" in "README_build.txt"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#Metadata-Update
        >. The gantry update-update action uses uses
        "dstar-checkout-corpus.sh"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#dstar-checkout-corpus.
        sh> to update the existing "CORPUS_ROOT" superstructure, and calls
        "/dstar/corpora/MYCORPUS/build.sh -update-meta"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#build.sh> in the in
        the embedded "dstar-buildhost" container to perform the index
        metadata update. By default, full build-logs
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Build-Logging> will be
        written to "CORPUS_ROOT/build/log/update-meta.*DATETIME*.log", and
        some progress information will be printed to the console via
        "cronit.perl -echo-preset=make-info"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#cronit.perl>. See
        "Metadata Update" in "README_build.txt"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#Metadata-Update
        > for more details.

    MYCORPUS post-metadata-update
        After updating a corpus with the update-meta action, proceed as you
        would after a build action, i.e. with consistency testing, staging,
        deployment, and post-deployment.

  Example: Corpus Build Archive
    MYCORPUS build archive
         $ dstar-gantry.sh -RO -c pnn_test archive-build
         $ rm -rf ~/dstar/corpora/pnn_test/{build,server,web}

        If your "CORPUS_ROOT/build/" directory is taking up too much space
        after deployment and doesn't participate in any superordinate
        metacorpora
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Superordinate-Metacorp
        ora>, incremental updates
        <https://kaskade.dwds.de/dstar/doc/README_build.html#Incremental-Upd
        ate>, or other operations requiring access to intermediate build
        files, then you may want to archive it and remove the original
        "CORPUS_ROOT" on the gantry host to save disk space (... but take
        care not to remove the archive while doing so). You can use the
        gantry "arhive-build" action for this purpose, which creates a
        gzipped tar archive
        "${dstar_archive_dir}/MYCORPUS.build-*DATETIME*.tar.gz", where
        *DATETIME* is a timestamp in *YYYY-MM-DD.HHMMSS* format and
        "${dstar_archive_dir}" is a container environment variable, by
        default "CORPUS_ROOT/archive/".

    MYCORPUS build archive restoration
        If you want to restore an archived corpus build directory, just
        unpack the archive file back into the "CORPUS_ROOT" directory:

         $ cd ~/dstar/corpora/MYCORPUS/archive
         $ tar xzf MYCORPUS.build-DATETIME.tar.gz -C ..

  Example: Corpus Deployment Archive
    MYCORPUS deployment archive
         $ dstar-gantry.sh -RO -c pnn_test archive-publish
         $ rm -rf ~/dstar/corpora/pnn_test/{server,web}

        You can create a "snapshot" of publishable corpus data from a
        "CORPUS_ROOT/build/" directory by means of the gantry
        "archive-publish" action. The resulting archive will be created as
        "${dstar_archive_dir}/MYCORPUS.publish-*DATETIME*.tar.gz", where
        *DATETIME* is a timestamp in *YYYY-MM-DD.HHMMSS* format and
        "${dstar_archive_dir}" is a container environment variable, by
        default "CORPUS_ROOT/archive/", and should contain all the index
        data required for a production runtime corpus instance on "RUNHOST"
        and/or "WEBHOST"
        <https://kaskade.dwds.de/dstar/doc/README.html#Hosts-and-Roles>.

    MYCORPUS deployment archive restoration
        If you want to restore an archived corpus deployment snapshot, just
        unpack the archive file back into the "CORPUS_ROOT/build/"
        directory:

         $ cd ~/dstar/corpora/MYCORPUS/archive
         $ tar xzf MYCORPUS.publish-DATETIME.tar.gz -C ../build

        To re-deploy the restored archive data to runtime "production"
        hosts, you should follow this up with a "publish" operation.

  Example: Corpus Removal
    "dstar-gantry" does not currently provide any shortcuts for removing an
    existing corpus, but it is straightforward to do by hand.

    MYCORPUS gantry host removal
         $ rm -rf ~/dstar/corpora/MYCORPUS/{build,server,web}

        To remove all corpus build and staging data, simply delete the
        relevant subdirectories from the gantry host. This will remove all
        dstar data created by the gantry actions "build", "update",
        "install", etc., including intermediate build files. If you have
        created any build- and/or publish-archives under
        "CORPUS_ROOT/archive/" which you want to save, you may want to move
        them to a different location (e.g. "$HOME/attic/"):

         $ mv ~/dstar/corpora/MYCORPUS/archive/*.tar.gz ~/attic/

        Otherwise, or if you wish to delete any old archives under under
        "CORPUS_ROOT/archive/", you can delete the entire "CORPUS_ROOT"
        directory:

         $ rm -rf ~/dstar/corpora/MYCORPUS/

    MYCORPUS decommissioning
        To decommission ("un-deploy") a corpus instance which has already
        been deployed to a runtime "production" "RUNHOST"
        <https://kaskade.dwds.de/dstar/doc/README.html#RUNHOST> and/or
        "WEBHOST" <https://kaskade.dwds.de/dstar/doc/README.html#WEBHOST>,
        follow the general procedure described under "Corpus Removal" in the
        dstar-HOWTO
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Removal>, where
        the gantry host acts as the "BUILDHOST", so gantry host removal
        replaces the "Freeze or remove build data"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Freeze-or-remove-build
        -data-optional> step in the general HOWTO.

  Example: Partial Corpus Build
    Before attempting to (partially) build a corpus, you should ensure that
    you have fulfilled all the "Common Prerequisites".

    "Partial" corpus builds are simply gantry corpus "build" operations
    which invoke only a subset of the full annotation and indexing
    <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Annotate-and-Build>
    procedure supported by the dstar build system, typically by setting the
    container environment variable "STAGES" to specify the desired build
    stages
    <https://kaskade.dwds.de/dstar/doc/README_build.html#Stage-Wise-Builds>.

    MYCORPUS partial build: tokenization
         $ dstar-gantry.sh -bg -c MYCORPUS -eSTAGES=1 build

        Executing a partial "stage1" build performs TEI-XML source checking
        ("build/src_catalog/"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#src_catalog>),
        and XML header extraction ("build/xml_header/"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#xml_header>),
        serialization and tokenization ("build/xml_tok/"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#xml_tok>) by
        default.

    MYCORPUS partial build: annotation
         $ dstar-gantry.sh -bg -c MYCORPUS -eSTAGES=2 build

        Executing a partial "stage2" build requires prior successful
        completion of a "stage1" build, and performs corpus analysis in
        ("build/cab_corpus/"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#cab_corpus>).

    MYCORPUS partial build: tokenization and annotation
         $ dstar-gantry.sh -bg -c MYCORPUS -eSTAGES="1 2" build

        You can combine multiple stages in a single partial build: the above
        example performs a "stage1" build followed by a "stage2" build in a
        single call.

    MYCORPUS partial build: pre-indexing
         $ dstar-gantry.sh -bg -c MYCORPUS -eSTAGES="1 2 3" STAGE3_DIRS="ddc_xml" build

        Partial builds are not restricted to whole stages: you can select
        specific "MYCORPUS/build/" subdirectories from a stage "*i*" by
        setting the "STAGE*i*_DIRS" variable. The above example performs all
        corpus build operations up to but not including configuration and
        compilation of the DDC index (i.e. full "stage1" and "stage2" builds
        and conversion of annoated documents to the legacy "ddc_xml"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#ddc_xml> format
        suitable for input to a "ddc_index" process).

    MYCORPUS partial build: incremental builds
         #-- partial build
         $ dstar-gantry.sh -fg -c MYCORPUS -eSTAGES="1 2" build
 
         #-- add some new sources
         $ cp -a ~/new/tei/xml/*.xml ~/dstar/sources/MYCORPUS/xml/
 
         #-- update partial build (changes only)
         $ dstar-gantry.sh -RO -bg -c MYCORPUS -eSTAGES="1 2" build

        Since the dstar build system is governed by GNU make, adding new
        sources to an existing partial build and re-invoking the partial
        build action should cause only those source documents which have
        been added or changed to be (re-)analyzed.

        Note that changes in any shared resources in "RESOURCES_DIR" may
        also cause *all* documents to be re-analyzed on a second build
        invocation: if you need to ensure stable resources for incremental
        (partial) builds, use a dedicated "RESOURCES_DIR" and specify the
        gantry "-RO" option for all but the initial build invocation.

        Note also that for incremental (partial) builds, a certain amount of
        computational overhead is required by GNU make to determine *which*
        sources are new rsp. whether any previously registered sources have
        been updated, which may be a problem for very large corpora with
        many small documents. If you need perform incremental builds on such
        a large corpus, you will probably need to optimize the frequency of
        your build calls to avoid wasting resources on unnecessary overhead,
        and/or manually partition your sources into disjoint "blocks"
        (treating each block as its own independent "corpus" for purposes of
        incremental partial gantry builds) and restricting your updates to a
        single block at a time (e.g. the smallest), or explicitly setting
        the "XML_SRC_DIRS"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#XML_SRC_DIRS>
        and/or "XML_SRC_FIND"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#XML_SRC_FIND>
        make variables to select only a particular subset (e.g. newly added
        files) of the available sources.

CAVEATS
  docker storage drivers
    Problems with runtime cross-layer copy operations have been observed in
    the past when using the "overlay2" docker storage driver, which is the
    default in recent version of the "docker-ce" package. On systems where
    these problems occurred, the "aufs" docker storage driver did not
    exhibit these issues; see
    <https://docs.docker.com/storage/storagedriver/aufs-driver/> for
    details.

    Even more recent debian releases no longer contain the "aufs" storage
    driver. The "overlay2" storage driver appears to work correctly under
    Debian 10 ("buster") using "docker-ce-5:19.03.12~3-0~debian-buster"
    ("Docker Community Edition", version 19.03.12) and linux kernel version
    4.19.0-6-amd64.

    It is currently recommended to try the default storage driver for your
    docker installation (probably "overlay2"), and only switch to "aufs" if
    you experience issues with cross-layer copy operations.

    Typically, the "aufs" driver can be enabled by editing the file
    /etc/docker/daemon.json to contain:

     {
      "storage-driver":"aufs"
     }

    ... and re-starting any docker services on the host machine.

  build responsibly
    If you build a corpus with "dstar-gantry" in a non-standard location
    and/or on a non-production host, you implicitly assume all resonsibility
    for keeping track of the intermediate build files in
    "CORPUS_ROOT/build/". Deploying only a corpus runtime instance to
    "production" hosts by means of the "publish" action is not sufficient to
    enable subsequent incremental corpus updates
    <https://kaskade.dwds.de/dstar/doc/README_build.html#Incremental-Update>
    , integration of new dstar functionality, or to enable many bug-fixes.
    You are free to delete or archive corpus build directories once you're
    done with them, but this is likely to make more work for everyone
    (yourself included) down the road. Consider archiving the corpus build
    directory if you need to save disk space.

  log changes
    When making changes to a corpus configuration in SVN, remember to log
    any changes to "DSTAR_ROOT/doc/Changes.txt"
    <https://kaskade.dwds.de/dstar/doc/HOWTO.html#doc%2FChanges.txt>. If you
    are using a "CORPUS_ROOT/config.local/"
    <https://kaskade.dwds.de/dstar/doc/README_build.html#Corpus-specific-cus
    tomizations-with-config.local> directory for corpus configuration
    outside of version control, remember to "build responsibly", and
    seriously consider checking the final configuration into version
    control.

KNOWN BUGS AND COMMON ERRORS
    Error response from daemon: ... no basic auth credentials
         dstar-gantry.sh: CMD: docker pull lex.dwds.de:443/dstar/dstar-buildhost:latest
         Error response from daemon: Get https://lex.dwds.de:443/v2/dstar/dstar-buildhost/manifests/latest: no basic auth credentials
         dstar-gantry.sh: ERROR: command `docker pull lex.dwds.de:443/dstar/dstar-buildhost:latest` exited abnormally with status 1

        This error can occur when executing a "gantry pull" if you neglected
        to run "docker login" for the ZDL docker registry. See "registry
        credentials".

    WARNING: neither CORPUS nor CORPUS_ROOT specified
         dstar-gantry.sh: WARNING: neither CORPUS nor CORPUS_ROOT specified (use the -c or -C options)

        This warning message usually indicates that you forgot to specify
        either a corpus label with the "-c CORPUS" option or a corpus root
        directory with the "-C CORPUS_ROOT" option. In this case, any
        corpus-dependent operation such as "build", "test", etc. is likely
        to fail ... unless you have set appropriate container variables such
        as "dstar_corpora" with the "-e VAR=VALUE" option and volume mounts
        with the "-v /PATH:/MOUNT" option. If the requested gantry action is
        not a corpus-dependent operation (e.g. "shell"), you can ignore this
        warning.

    WARNING: no CORPUS_SRC directory specified
         dstar-gantry.sh: WARNING: no CORPUS_SRC directory specified (expect trouble if you're trying to (re-)index a corpus)

        This warning message indicates that "dstar-gantry.sh" could not
        locate a corpus source directory in any of the default locations,
        and that you haven't specified one with the "-S CORPUS_SRC" option.
        Source-dependent operations such as "build", "update", and
        "update-meta" are likely to fail unless you specify additional
        container variables and/or volume mounts.

        If the requested gantry action is a source-independent operation
        such as "install", "publish", or "run", you can ignore this warning.

    Conflict. The container name "/dstar-gantry-MYCORPUS" is already in use
         docker:
          Error response from daemon:
          Conflict.
          The container name "/dstar-gantry-MYCORPUS" is already in use by container "51cea72ba7cf14a5a44ee373b6f81f1b07da5b947e4f852cea8566b11017752d".
          You have to remove (or rename) that container to be able to reuse that name.
         See 'docker run --help'.

        This error is emitted by "docker run"
        <https://docs.docker.com/engine/reference/run/> if you attempt to
        invoke a "dstar-gantry" operation for a "CORPUS" for which there is
        already a docker container running (or if you attempt to invoke
        multiple simultaneous "dstar-gantry" operations without specifying
        any "CORPUS"). By default, "dstar-gantry.sh" implicitly prepends the
        "--name=dstar-gantry-MYCORPUS"
        <https://docs.docker.com/engine/reference/run/#name---name> option
        to "DOCKER_OPTS" when invoking the embedded container. Since "docker
        run" <https://docs.docker.com/engine/reference/run> will refuse to
        run 2 different containers of the same name (as the error message
        clearly states), at most one gantry container can be running per
        corpus and "GANTRYHOST" by default.

        To see which "docker" containers are currently running, you can use
        the "docker ps"
        <https://docs.docker.com/engine/reference/commandline/ps/> command
        (also check "docker ps -a"
        <https://docs.docker.com/engine/reference/commandline/ps/> to
        include stopped or terminated containers).

        If you *really* want to run a second docker container for a given
        "CORPUS", you will need to override the default container name in
        "DOCKER_OPTS", e.g.:

         $ dstar-gantry.sh -c MYCORPUS -p 8001 run -- -name=MYCORPUS-8001

        If you use an alternative container name for a staging instance with
        the gantry "run" action, you will need to adjust the "docker kill"
        <https://docs.docker.com/engine/reference/commandline/kill/> command
        accordingly:

         $ docker kill MYCORPUS-8001

    E000013 ... Permission denied
         CMD /home/ddc-dstar/dstar/bin/dstar-nice.sh svn co --depth=files svn+ssh://svn.dwds.de/home/svn/dev/ddc-dstar/trunk/corpus MYCORPUS
         svn: E000013: Can't create directory '/home/ddc-dstar/dstar/corpora/MYCORPUS/.svn': Permission denied

        "Permission denied" errors from SVN during corpus checkout in the
        embedded "dstar-buildhost" container can occur whenever you attempt
        to operate on a "CORPUS_ROOT" working copy for which the gantry
        build "USER" and/or "GROUP" does not have sufficient permissions.
        Typically, this is because the "CORPUS_ROOT" checkout is owned by a
        different user. If you consistently use the default "ddc-admin" user
        for corpus operations as recommended in the dstar-HOWTO
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Play-nicely>, you
        should never encounter this error.

        How you solve this problem is entirely up to you. Some possibilities
        include:

        *   Ask the current owner or an administrator ("root") to alter the
            permissions recursively using standard UNIX tools ("chown -R",
            "chmod -R"), or do so yourself with "sudo".

        *   If you have read permission, you can copy the directory to a new
            location with appropriate permissions and specify the path to
            your new copy using the "-C CORPUS_ROOT" option. This may use a
            lot of additional disk space, so it's best to avoid this if
            possible.

        *   You can create a new "CORPUS_ROOT" directory with appropriate
            permissions and specify its location with the "-C CORPUS_ROOT"
            option. This is even more wasteful than copying the original
            directory.

        ... see also "Ownership and Permissions" in the dstar-HOWTO
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Ownership-and-Permissi
        ons>.

    AH00526: ... Unknown Authn provider: external
         INFO spawned: 'apache' with pid 1417
         apache stderr | AH00526: Syntax error on line 32 of /etc/apache2/sites-enabled/020-dstar-MYCORPUS.conf: Unknown Authn provider: external
         INFO exited: apache (exit status 1; not expected)
         apache stdout | Action '-D FOREGROUND -e notice' failed.
         The Apache error log may have more information.
         INFO gave up: apache entered FATAL state, too many start retries too quickly

        This error message is emitted by the apache
        <https://httpd.apache.org/> HTTP server to the "docker logs"
        <https://docs.docker.com/engine/reference/commandline/logs/> console
        of a container "run" action if the corpus configuration
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Corpus-Configuration>
        set the "WEB_SITE_AUTH_EXTERNAL"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#WEB_SITE_AUTH_E
        XTERNAL> variable to a non-trivial value (e.g. "auth_dwdsdb"). The
        "dstar-buildhost" does not currently support the apache external
        authorization module, so you should specify an override
        "WEB_SITE_AUTH_EXTERNAL=no"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#WEB_SITE_AUTH_E
        XTERNAL> with the "-e VAR=VALUE" option. It's probably a good idea
        to force "WEB_SITE_PUBLIC=yes"
        <https://kaskade.dwds.de/dstar/doc/README_build.html#WEB_SITE_PUBLIC
        > in staging containers too:

         $ dstar-gantry.sh -c MYCORPUS -eWEB_SITE_AUTH_EXTERNAL=no -eWEB_SITE_PUBLIC=yes run

        Future versions of gantry may implicitly set these values for
        staging instances.

    connection reset by peer
         Connection reset by peer.
         The connection was reset.
         The connection to the server was reset while the page was loading.

        This message may appear (e.g. in your local browser) when attempting
        to access a staging instance from your local workstation, in
        particular if you are using an ssh tunnel
        <https://www.ssh.com/ssh/tunneling/example> for port-forwarding.
        Some success has been reported using the "-g" option to "ssh" when
        setting up the tunnel as suggested here
        <https://serverfault.com/questions/427703/ssh-tunnel-doesnt-work>,
        i.e.

         WORKSTATION $ ssh -g 8002:GANTRYHOST:8001 -N GANTRYHOST & gantry_tunnel_pid=$!

    bind: Address already in use
         bind: Address already in use
         channel_setup_fwd_listener_tcpip: cannot listen to port: 8000
         Could not request local forwarding.

        This error may appear when attempting to set up an an ssh tunnel
        <https://www.ssh.com/ssh/tunneling/example> for accessing a staging
        instance behind a firewall. It indicates that the local port you
        have chosen for the tunnel is already allocated to another process
        (which might be a previous invocation of the same ssh-tunnel you
        have forgotten to kill). Either kill the obstructing process or
        choose a different local port for your ssh tunnel; see also
        <https://askubuntu.com/questions/447820/ssh-l-error-bind-address-alr
        eady-in-use>.

    svn: E170013: Unable to connect to a repository
         svn: E170013: Unable to connect to a repository at URL 'svn+ssh://svn.dwds.de/home/svn/dev/'
         svn: E210002: To better debug SSH connection problems, remove the -q option from 'ssh' in the [tunnels] section of your Subversion configuration file.
         svn: E210002: Network connection closed unexpectedly

        This error message is emitted if the dstar SVN repository is
        inaccessible, e.g. because the virtual machine on which it resides
        has catastrophically failed. It may also indicate an error with the
        gantry host's network connectivity. In an emergency situtation if
        the dstar SVN repository is down when you need to build a new corpus
        (without an existing "CORPUS_ROOT"), you can use the
        "dstar-buildhost" image to manually create an appropriate
        "CORPUS_ROOT" by calling:

         $ dstar-gantry.sh -c MYCORPUS -- -- env exec dstar-nice.sh cp -naT corpus.template corpora/MYCORPUS

        In order to disable implicit SVN update during dstar-gantry
        operations, you should also set the
        "dstar_checkout_corpus_opts="-force -dummy"" container environment
        variable as long as the SVN repository is inaccessible. If you need
        to publish corpora in the absence of a working dstar SVN repository,
        you should consider setting "PUBLISH_SVN_CHECK=no",
        "SERVER_PUBLISH_CHECKOUT=no", "WEB_PUBLISH_CHECKOUT=no", and
        "PUBLISH_REGISTER=no", in which case you will need to manually
        create appropriate runtime checkouts
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#Runtime-Checkouts> on
        "RUNHOST" and/or "WEBHOST" (hint: you can use the gantry template
        for these too). Altering these variables from their default values
        is NOT recommended in general and should be considered a last resort
        for emergency use only.

    No rule to make target 'init-rml'. Stop.
         make: Entering directory '/home/ddc-dstar/dstar/corpora/MYCORPUS/server'
         make: *** No rule to make target 'init-rml'.  Stop.
         make: Leaving directory '/home/ddc-dstar/dstar/corpora/MYCORPUS/server'
         build EVAL: echo '/home/ddc-dstar/dstar/corpora/MYCORPUS/server' >>/etc/default/ddc_servers
         build RUN: dstar-nice.sh make -e -s -C ../corpora/MYCORPUS/web corpus.ttk custom.ttk dstar-rc site-rc
         make: *** No rule to make target 'corpus.ttk'.  Stop.
         build ERROR: failed to initialize dstar configuration for web directory '../corpora/MYCORPUS/web'

        This error has been observed when attempting to run a staging
        instance for a corpus whose "CORPUS_ROOT/server" directory was
        missing the requisite shared dstar infrastructure code (in this
        case, "CORPUS_ROOT/server/Makefile") after failure of the
        infrastructure SVN server. To avoid this error, ensure that your
        "CORPUS_ROOT" directory is a valid SVN working copy, and resolve any
        conflicts reported by "svn status -u CORPUS_ROOT" before attempting
        to install or run a staging instance for that corpus.

    SVN conflicts
         Skipped 'corpora/MYCORPUS/...' -- Node remains in conflict
         ...
         Summary of conflicts:
           Skipped paths: N
           Tree conflicts: N

        SVN conflicts can arise when attempting to update a "CORPUS_ROOT"
        (sub)directory which contains inconsistent SVN metadata. SVN
        conflicts must be resolved manually; see
        <http://svnbook.red-bean.com/> for details.

    Warning: the RSA host key for 'HOST' differs from the key for the IP
    address 'IPADDR'
         Warning: the RSA host key for 'HOST' differs from the key for the IP address 'IPADDR'
         Offending key for IP in /home/dstar-build/.ssh/known_hosts:10
         Matching host key in /home/dstar-build/.ssh/known_hosts:4

        This warning message can arise due to a stale "known_hosts" file for
        the ephemeral "dstar-build" user in the running "dstar-buildhost"
        container. It should be non-fatal, but please report it if you
        encounter it during a "dstar-gantry.sh" operation.

    dstar.perl: could not connect to DDC server localhost port PORT:
    Connection refused
        This error can appear in a browser when attempting to access a
        staging instance for which the "ddc_daemon" process in
        "CORPUS_ROOT/server" has not (yet) successfully started. Check the
        "docker logs"
        <https://docs.docker.com/engine/reference/commandline/logs/> for the
        staging container and/or its supervisord <http://supervisord.org/>
        GUI at "http://CONTAINER:9001" for more details.

    Cannot allocate memory
         (server-main[pid=3101]) > Error! Cannot load project index/catch22/catch22.con: cannot load index of project index/catch22/catch22.con: ddcMMap::open(): mmap() failed for file 'index/catch22/catch22._storage_WordSep': Cannot allocate memory 
         ddc_daemon[3101]: (server-main[pid=3101]) > Error! Cannot load project index/catch22/catch22.con: cannot load index of project index/catch22/catch22.con: ddcMMap::open(): mmap() failed for file 'index/catch22/catch22._storage_WordSep': Cannot allocate memory 
         terminate called after throwing an instance of 'std::runtime_error'

        This message can occur if the "ddc_daemon" process for a staging
        instance in "CORPUS_ROOT/server" is unable to allocate sufficient
        virtual memory <https://en.wikipedia.org/wiki/Virtual_memory>
        address space to accomodate its index data, possibly due to a
        misconfiguration of the dstar make variable "SERVER_ULIMIT_MEM"
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#RUNHOST-memory>. Try
        raising the value of "SERVER_ULIMIT_MEM" or setting it to the empty
        string: if the error message is no longer raised, report the
        adjustment and/or modify the appropriate configuration file(s) (e.g.
        "CORPUS.mak").

        Contemporary 64-bit linux architectures can handle up to 2^48 bytes
        (= 256 TB) of virtual memory address space on a single machine,
        regardless of the amount of physical RAM installed, so this error is
        unlikely to be caused by machine limitations on the gantry host
        itself.

    other errors
        See "COMMON ERRORS" in the dstar-HOWTO
        <https://kaskade.dwds.de/dstar/doc/HOWTO.html#COMMON-ERRORS>.

SEE ALSO
    *   The dstar README <https://kaskade.dwds.de/dstar/doc/README.html> and
        the references mentioned therein describe the D* framework in more
        detail. Most of the D* documentation available under
        "https://kaskade.dwds.de/dstar/doc"
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

COPYRIGHT AND LICENSE
    Copyright (C) 2020 by Bryan Jurish

    This package is free software; you can redistribute it and/or modify it
    under the terms of the European Union Public Licence. See the file
    LICENSE in the root directory of the source distribution for details.

