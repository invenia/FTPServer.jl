using FTPServer
using FTPClient
using Memento
using Memento.TestUtils: @test_log
using Test

@testset "FTPServer.jl" begin
    FTPServer.init()

    @testset "no-ssl" begin
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
    @testset "no-ssl debug true" begin
        @test_log(
            FTPServer.LOGGER,
            "info",
            r"^Running Command:.*",
            FTPServer.Server(; debug_command=true),
        )
    end
    @testset "ssl - $mode - $gen_cert" for mode in (:explicit, :implicit), gen_cert in (true, false)
        FTPServer.serve(; security=mode, force_gen_certs=gen_cert) do server
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

    FTPServer.cleanup()

    @test !isfile(FTPServer.CERT)
    @test !isfile(FTPServer.KEY)
    @test !isdir(FTPServer.HOMEDIR)
end
