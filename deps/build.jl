using Conda

# OpenSSL 1.1.1e added in a breaking change that is affecting many FTP clients.
# For now, we can pin to 1.1.1d until it is fixed.
# https://github.com/openssl/openssl/issues/11381
# https://github.com/openssl/openssl/issues/11378
Conda.add("openssl==1.1.1d")
