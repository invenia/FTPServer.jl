using Compat
using Compat.Test
using FTPLib
using FTPClient


@testset "FTPLib.jl" begin
    @testset "no-ssl" begin
        FTPLib.setup_server()
        server = FTPLib.FTPServer()

        opts = (
            :hostname => FTPLib.hostname(server),
            :port => FTPLib.port(server),
            :username => FTPLib.username(server),
            :password => FTPLib.password(server),
        )

        try
            options = RequestOptions(; opts..., ssl=false)
            ctxt, resp = ftp_connect(options)
            @test resp.code == 226
        finally
            close(server)
        end
    end
    @testset "ssl - $mode" for mode in (:explicit, :implicit)
        FTPLib.setup_server()
        server = FTPLib.FTPServer(security=mode)

        opts = (
            :hostname => FTPLib.hostname(server),
            :port => FTPLib.port(server),
            :username => FTPLib.username(server),
            :password => FTPLib.password(server),
            :ssl => true,
            :implicit => mode === :implicit,
            :verify_peer => false,
        )

        try
            options = RequestOptions(; opts...)
            # Test implicit/exlicit ftp ssl scheme is set correctly
            @test options.uri.scheme == (mode === :implicit ? "ftps" : "ftpes")
            ctxt, resp = ftp_connect(options)
            @test resp.code == 226
        finally
            close(server)
        end
    end

end
