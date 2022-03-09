#------------------------------------------------------------------------------
# Copyright (c) 2021, 2022, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from cryptography import x509
from cryptography.hazmat.primitives.ciphers import algorithms, modes, Cipher
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf import pbkdf2

DN_REGEX = '(?:^|,\s?)(?:(?P<name>[A-Z]+)=(?P<val>"(?:[^"]|"")+"|[^,]+))+'
PEM_WALLET_FILE_NAME = "ewallet.pem"

def decrypt_cbc(key, encrypted_text):
    """
    Decrypt the given text using the given key.
    """
    iv = bytes(16)
    algo = algorithms.AES(key)
    cipher = Cipher(algo, modes.CBC(iv))
    decryptor = cipher.decryptor()
    return decryptor.update(encrypted_text)


def encrypt_cbc(key, plain_text):
    """
    Encrypt the given text using the given key.
    """
    block_size = 16
    iv = bytes(block_size)
    algo = algorithms.AES(key)
    cipher = Cipher(algo, modes.CBC(iv))
    encryptor = cipher.encryptor()
    n = block_size - len(plain_text) % block_size
    if n:
        plain_text += (bytes([n]) * n)
    return encryptor.update(plain_text) + encryptor.finalize()


def get_derived_key(key, salt, length, iterations):
    """
    Return a derived key using PBKDF2.
    """
    kdf = pbkdf2.PBKDF2HMAC(algorithm=hashes.SHA512(), salt=salt,
                            length=length, iterations=iterations)
    return kdf.derive(key)


def get_server_dn_matches(sock, expected_dn):
    """
    Return a boolean indicating if the server distinguished name (DN) matches
    the expected distinguished name (DN).
    """
    cert_data = sock.getpeercert(binary_form=True)
    cert = x509.load_der_x509_certificate(cert_data)
    server_dn = cert.subject.rfc4514_string()
    expected_dn_dict = dict(re.findall(DN_REGEX, expected_dn))
    server_dn_dict = dict(re.findall(DN_REGEX, server_dn))
    return server_dn_dict == expected_dn_dict


def get_ssl_socket(sock, params):
    """
    Returns a wrapped SSL socket given a socket and the parameters supplied by
    the user.
    """
    ssl_context = ssl.create_default_context()
    if params.wallet_location is not None:
        pem_file_name = os.path.join(params.wallet_location,
                                     PEM_WALLET_FILE_NAME)
        if not os.path.exists(pem_file_name):
            errors._raise_err(errors.ERR_WALLET_FILE_MISSING,
                              name=pem_file_name)
        ssl_context.load_cert_chain(pem_file_name,
                                    password=params.wallet_password)
    if params.ssl_server_dn_match and params.ssl_server_cert_dn is None:
        sock = ssl_context.wrap_socket(sock, server_hostname=params.host)
    else:
        ssl_context.check_hostname = False
        sock = ssl_context.wrap_socket(sock)
    if params.ssl_server_dn_match and params.ssl_server_cert_dn is not None:
        if not get_server_dn_matches(sock, params.ssl_server_cert_dn):
            errors._raise_err(errors.ERR_INVALID_SERVER_CERT_DN)
    return sock
