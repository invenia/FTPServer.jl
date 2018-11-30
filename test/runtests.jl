using Compat
using Compat.Test
using FTPServer
using FTPClient


@testset "FTPServer.jl" begin
    @testset "no-ssl" begin
        FTPServer.setup_server()

        FTPServer.serve() do server
            opts = (
                :hostname => FTPServer.hostname(server),
                :port => FTPServer.port(server),
                :username => FTPServer.username(server),
                :password => FTPServer.password(server),
            )

            options = RequestOptions(; opts..., ssl=false)
            ctxt, resp = ftp_connect(options)
            @test resp.code == 226
        end
    end
    @testset "ssl - $mode" for mode in (:explicit, :implicit)
        FTPServer.setup_server()

        FTPServer.serve(; security=mode) do server
            opts = (
                :hostname => FTPServer.hostname(server),
                :port => FTPServer.port(server),
                :username => FTPServer.username(server),
                :password => FTPServer.password(server),
                :ssl => true,
                :implicit => mode === :implicit,
                :verify_peer => false,
            )

            options = RequestOptions(; opts...)
            # Test implicit/exlicit ftp ssl scheme is set correctly
            @test options.uri.scheme == (mode === :implicit ? "ftps" : "ftpes")
            ctxt, resp = ftp_connect(options)
            @test resp.code == 226
        end
    end

end
