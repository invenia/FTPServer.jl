module FTPServer

import Base: Process
import Base: close
using Conda
using Memento
using PyCall
using Random: randstring
const LOGGER = getlogger(@__MODULE__)

const pyopenssl_crypto = PyNULL()
const pyopenssl_SSL = PyNULL()
const pyftpdlib_authorizers = PyNULL()
const pyftpdlib_handlers = PyNULL()
const pyftpdlib_servers = PyNULL()

# Defaults from pyftpdlib example
const HOST = "localhost"
const PERM = "elradfmwM"

const SCRIPT = abspath(dirname(@__FILE__), "server.py")
const ROOT = abspath(joinpath(dirname(dirname(@__FILE__)), "deps", "usr", "ftp"))
const HOMEDIR = joinpath(ROOT, "data")
const CERT = joinpath(ROOT, "test.crt")
const KEY = joinpath(ROOT, "test.key")
const PYTHON_CMD = joinpath(
    Conda.PYTHONDIR, Sys.iswindows() ? "python.exe" : "python"
)

function __init__()
    Memento.register(LOGGER)

    copy!(pyopenssl_crypto, pyimport_conda("OpenSSL.crypto", "OpenSSL"))
    copy!(pyopenssl_SSL, pyimport_conda("OpenSSL.SSL", "OpenSSL"))

    # Note: For `pyftpdlib` we'll specify an exact version to make behaviour of FTPServer.jl
    # consistent when rolling back to an earlier version.
    # For details see: https://github.com/invenia/FTPClient.jl/issues/91#issuecomment-632698841
    copy!(pyftpdlib_servers, pyimport_conda("pyftpdlib.servers", "pyftpdlib==1.5.4", "invenia"))

    mkpath(ROOT)
end


mutable struct Server
    homedir::AbstractString
    port::Int
    username::AbstractString
    password::AbstractString
    permissions::AbstractString
    security::Symbol
    process::Process
    io::IO
end

"""
    Server(
        homedir::AbstractString=$HOMEDIR;
        username::AbstractString="",
        password::AbstractString="",
        permissions::AbstractString=$PERM,
        security::Symbol=:none,
        force_gen_certs::Bool=true,
        debug_command::Bool=false,
    )

A Server stores settings to create a pyftpdlib server.

# Arguments
- `homedir::AbstractString=$HOMEDIR`: Directory where you want to store your data for the
  test server.

# Keywords
- `username::AbstractString=""`: Default login username. Defaults to 'userXXXX' where 'XXXX'
  is a number between 1 and 9999.
- `password::AbstractStringi=""`: Default login password. Defalts to a random string of 40
  characters.
- `permission::AbstractString=$PERM`: Default user read/write permissions.
- `security::Symbol=:none`: Security method to use for connecting (options: `:none`,
  `:implicit`, `:explicit`). Passing in `:none` will use FTP and passing in `:implicit` or
  `:explicit` will use the appropriate FTPS connection.
- `force_gen_certs::Bool=true`: Force regeneration of certificate and key file.
- `debug_command::Bool=false`: Print out the python command being used, for debugging
  purposes.
"""
function Server(
    homedir::AbstractString=HOMEDIR;
    username::AbstractString="",
    password::AbstractString="",
    permissions::AbstractString=PERM,
    security::Symbol=:none,
    force_gen_certs::Bool=true,
    debug_command::Bool=false,
)
    if isempty(username)
        username = string("user", rand(1:9999))
    end
    if isempty(password)
        password = randstring(40)
    end

    cmd = `$PYTHON_CMD $SCRIPT $username $password $homedir --permissions $permissions`
    if security != :none
        cmd = `$cmd --tls $security --cert-file $CERT --key-file $KEY`

        if force_gen_certs
            cmd = `$cmd --force-gen-certs`
        end
    end

    # If we're having issues with the above command, it can be useful to print it out so we
    # can run the command against the python script itself to see if it gives us any extra
    # insight.
    if debug_command
        info(LOGGER, "Running Command: $cmd")
    end

    # Note: open(::AbstractCmd, ...) won't work here as it doesn't allow us to capture
    # STDERR.
    io = Pipe()
    process = run(pipeline(cmd, stdout=io, stderr=io), wait=false)

    # Grab the Port value from the python script output
    line = readline(io)
    while !occursin("starting FTP", line)
        line = readline(io)
    end
    m = match(r"starting FTP.* server on .*:(?<port>\d+)", line)

    # If we found the port, store the server data in an object, else show an error
    if m !== nothing
        port = parse(Int, m[:port])
        Server(homedir, port, username, password, permissions, security, process, io)
    else
        kill(process)
        error(line, String(readavailable(io)))  # Display traceback
    end
end

"""
    serve(f, args...; kwargs...)

Passes `args` and `kwargs` to the `Server` constructor and runs the function `f` by passing
in the `server` instance. Upon completion the `server` will automatically be shutdown.
"""
function serve(f::Function, args...; kwargs...)
    server = Server(args...; kwargs...)

    try
        f(server)
    finally
        close(server)
    end
end

hostname(server::Server) = HOST
port(server::Server) = server.port
username(server::Server) = server.username
password(server::Server) = server.password
close(server::Server) = kill(server.process)

localpath(server::Server, path::AbstractString) = joinpath(
    server.homedir, split(path, '/')...
)

function tempfile(path::AbstractString)
    content = randstring(rand(1:100))
    open(path, "w") do fp
        write(fp, content)
    end
    return content
end

function setup_home(dir::AbstractString)
    mkdir(dir)
    tempfile(joinpath(dir, "test_download.txt"))
    tempfile(joinpath(dir, "test_download2.txt"))
    mkdir(joinpath(dir, "test_directory"))
end

"""
    init()

Creates a test $HOMEDIR with a few sample files if one hasn't already been setup.

```
$HOMEDIR/test_download.txt
$HOMEDIR/test_download2.txt
$HOMEDIR/test_directory/
````
"""
init() = isdir(FTPServer.HOMEDIR) || setup_home(FTPServer.HOMEDIR)

"""
    cleanup()

Cleans up the default FTPServer.ROOT directory:

- $HOMEDIR
- $CERT
- $KEY
"""
function cleanup()
    rm(FTPServer.HOMEDIR, recursive=true)
    isfile(FTPServer.CERT) && rm(FTPServer.CERT)
    isfile(FTPServer.KEY) && rm(FTPServer.KEY)
end

"""
    uri(server::Server)

Create an FTP URI from an FTP server object.

# Arguments
- `server::Server`: FTPServer object
"""
function uri(server::Server)
    ftp_type = if server.security === :implicit
        "ftps"
    server.security === :explicit
        "ftpes"
    else
        "ftp"
    end

    string(
        "$ftp_type://$(username(server)):$(password(server))",
        "@$(hostname(server)):$(port(server))",
    )
end

end # module
