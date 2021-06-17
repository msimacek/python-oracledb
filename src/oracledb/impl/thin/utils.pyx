#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef bint DEBUG_PACKETS = ("PYO_DEBUG_PACKETS" in os.environ)

def _print_packet(operation, socket_fileno, view):
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
