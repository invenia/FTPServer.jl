import argparse
import logging
from pathlib import Path

from OpenSSL import crypto
from pyftpdlib.authorizers import DummyAuthorizer
from pyftpdlib.handlers import FTPHandler, TLS_FTPHandler
from pyftpdlib.servers import FTPServer

# Required packages: pyftpdlib, pyopenssl


# https://github.com/giampaolo/pyftpdlib/issues/160
class TLSImplicit_FTPHandler(TLS_FTPHandler):
    def handle(self):
        self.secure_connection(self.ssl_context)

    def handle_ssl_established(self):
        TLS_FTPHandler.handle(self)

    def ftp_AUTH(self, arg):
        self.respond("550 not supposed to be used with implicit SSL.")


def create_self_signed_cert(cert_file, key_file, hostname):
    # from https://gist.github.com/ril3y/1165038

    # create a key pair
    k = crypto.PKey()
    k.generate_key(crypto.TYPE_RSA, 1024)

    # create a self-signed cert
    cert = crypto.X509()
    cert.get_subject().CN = hostname
    cert.set_serial_number(1000)
    cert.gmtime_adj_notBefore(0)
    cert.gmtime_adj_notAfter(10 * 365 * 24 * 60 * 60)
    cert.set_issuer(cert.get_subject())
    cert.set_pubkey(k)
    cert.sign(k, "sha256")

    with cert_file.open("wt") as fp:
        fp.write(crypto.dump_certificate(crypto.FILETYPE_PEM, cert).decode("utf-8"))
    with key_file.open("wt") as fp:
        fp.write(crypto.dump_privatekey(crypto.FILETYPE_PEM, k).decode("utf-8"))


def main():
    args = parse_args()
    cert_file = args.cert_file
    key_file = args.key_file

    if args.debug:
        logging.basicConfig(level=logging.DEBUG)

    # If either the cert or key doesn't exist, then we need to regenerate both of them
    # If force_gen is True, then we regenerate both the cert and key regardless
    # We only need to do this if we're using TLS
    if args.tls and (
        not cert_file.exists() or not key_file.exists() or args.force_gen_certs
    ):
        create_self_signed_cert(cert_file, key_file, args.hostname)

    # Adapted from:
    # https://pyftpdlib.readthedocs.io/en/latest/tutorial.html#a-base-ftp-server
    authorizer = DummyAuthorizer()
    authorizer.add_user(args.username, args.password, args.root, perm=args.permissions)

    if args.tls == "implicit":
        handler = TLSImplicit_FTPHandler
    elif args.tls == "explicit":
        handler = TLS_FTPHandler
    else:
        handler = FTPHandler

    handler.authorizer = authorizer

    if args.passive_ports:
        passive = tuple(int(p) for p in args.passive_ports.split("-"))
        if len(passive) > 2:
            raise ValueError("Passive port needs to be a range of two values")

        if len(passive) == 1:
            handler.passive_ports = range(passive[0], passive[0] + 1)
        else:
            handler.passive_ports = range(passive[0], passive[1] + 1)

    if args.tls:
        handler.certfile = str(cert_file)
        handler.keyfile = str(key_file)
        handler.tls_control_required = "control" in args.tls_require
        handler.tls_data_required = "data" in args.tls_require

    server = FTPServer((args.hostname, args.port), handler)
    server.serve_forever()


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("username", type=str, help="FTP Server Username")
    parser.add_argument("password", type=str, help="FTP Server Password")
    parser.add_argument("root", type=str, help="FTP Server root directory")
    parser.add_argument(
        "--permissions", type=str, default="elr", help="FTP Server permissions"
    )
    parser.add_argument(
        "--hostname", type=str, default="localhost", help="hostname to use"
    )
    parser.add_argument(
        "--port", type=int, default=0, help="By default the port will be randomized"
    )
    parser.add_argument(
        "--passive-ports", type=str, help="port or port range. ex: 1337, 1337-1447"
    )
    parser.add_argument(
        "--tls",
        type=str,
        choices=["implicit", "explicit"],
        help="use TLS in implicit or explicit mode",
    )
    parser.add_argument(
        "--tls-require",
        type=list,
        choices=["control", "data"],
        nargs="*",
        default=[],
        help="Determine if TLS should be established on the data or control channel",
    )
    parser.add_argument(
        "--cert-file",
        type=lambda p: Path(p).absolute(),
        default=Path("test.crt"),
        help="Path to the certificate file",
    )
    parser.add_argument(
        "--key-file",
        type=lambda p: Path(p).absolute(),
        default=Path("test.key"),
        help="Path to the key file",
    )
    parser.add_argument(
        "--force-gen-certs",
        action="store_true",
        help="Regenerate certificate and key files regardless if they exist or not",
    )
    parser.add_argument("--debug", action="store_true", help="Display DEBUG messages")

    return parser.parse_args()


if __name__ == "__main__":
    main()
