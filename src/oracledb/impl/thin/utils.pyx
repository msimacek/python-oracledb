#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef bint DEBUG_PACKETS = ("PYO_DEBUG_PACKETS" in os.environ)

class ConnectConstants:

    def __init__(self):
        self.program_name = sys.executable
        self.machine_name = socket.gethostname()
        self.pid = str(os.getpid())
        self.user_name = getpass.getuser()
        self.terminal_name = "unknown"
        self.sanitized_program_name = self._sanitize(self.program_name)
        self.sanitized_machine_name = self._sanitize(self.machine_name)
        self.sanitized_user_name = self._sanitize(self.user_name)

    def _sanitize(self, value):
        """
        Sanitize the value by replacing all the "(", ")" and "=" characters
        with "?". These are invalid characters within connect data.
        """
        return value.replace("(", "?").replace(")", "?").replace("=", "?")

_connect_constants = ConnectConstants()

def _get_connect_data(params):
    """
    Return the connect data required by the listener in order to connect.
    """
    constants = _connect_constants
    server_type = "(SERVER=POOLED)" if params.enable_drcp else ""
    identity = f"(SERVICE_NAME={params.service_name})" \
            if params.service_name is not None or params.sid is None \
            else f"(SID={params.sid})"
    cid = f"(PROGRAM={constants.sanitized_program_name})" + \
          f"(HOST={constants.sanitized_machine_name})" + \
          f"(USER={constants.sanitized_user_name})"
    return f"(DESCRIPTION=(ADDRESS=(PROTOCOL={params.protocol.upper()})" + \
           f"(HOST={params.host})(PORT={params.port}))" + \
           f"(CONNECT_DATA={identity}{server_type}(CID={cid})))"


def _print_packet(operation, socket_fileno, view):
    """
    Print the packet content in a format suitable for debugging.
    """
    offset = 0
    hex_data = view.hex().upper()
    current_date = datetime.datetime.now().isoformat(sep=" ",
                                                     timespec="milliseconds")
    print(current_date, f"[socket: {socket_fileno}]", operation)
    while hex_data:
        line_hex_data = hex_data[:16]
        hex_data = hex_data[16:]
        hex_dump_values = []
        printable_values = []
        for i in range(0, len(line_hex_data), 2):
            hex_byte = line_hex_data[i:i + 2]
            hex_dump_values.append(hex_byte)
            byte_val = ord(bytes.fromhex(hex_byte))
            char_byte = chr(byte_val)
            if char_byte.isprintable() and byte_val < 128 \
                    and char_byte != " ":
                printable_values.append(char_byte)
            else:
                printable_values.append(".")
        while len(hex_dump_values) < 8:
            hex_dump_values.append("  ")
            printable_values.append(" ")
        print("%.4d : %s  |%s|" % (offset, " ".join(hex_dump_values),
                "".join(printable_values)))
        offset += 8
    print()
