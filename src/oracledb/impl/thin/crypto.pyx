#------------------------------------------------------------------------------
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from cryptography import x509
from cryptography.hazmat.primitives.ciphers import algorithms, modes, Cipher
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf import pbkdf2

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


def get_server_dn(sock):
    """
    Return the server distinguished name (DN) given a socket.
    """
    cert_data = sock.getpeercert(binary_form=True)
    cert = x509.load_der_x509_certificate(cert_data)
    return cert.subject.rfc4514_string()


def get_ssl_socket(sock, params):
    """
    Returns a wrapped SSL socket given a socket and the parameters supplie by
    the user.
    """
    ssl_context = ssl.create_default_context()
    sock = ssl_context.wrap_socket(sock, server_hostname=params.host)
    if params.ssl_server_dn_match and params.ssl_server_cert_dn is not None:
        server_dn = get_server_dn(sock)
        if server_dn != params.ssl_server_cert_dn:
            errors._raise_err(errors.ERR_INVALID_SERVER_CERT_DN)
    return sock
