#------------------------------------------------------------------------------
# Copyright (c) 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# oracle_deprecated.py
#
# Overrides the 'deprecated' directive so that it can a componment name can be
# used in conjunction with the version.
#------------------------------------------------------------------------------


from docutils import nodes
from docutils.parsers.rst import Directive
from sphinx import addnodes

class DriverDeprecated(Directive):
    has_content = True
    required_arguments = 1
    optional_arguments = 0
    final_argument_whitespace = True

    def run(self):
        node = addnodes.versionmodified()
        node.document = self.state.document
        node['type'] = self.name
        node['version'] = self.arguments[0]
        text = 'Deprecated since {}.'.format(self.arguments[0])
        classes = ['versionmodified', 'deprecated']
        para = nodes.paragraph('', '',
                               nodes.inline('', text, classes=classes),
                               translatable=False)
        node.append(para)
        ret: List[Node] = [node]
        return ret

def setup(app):
    app.add_directive("deprecated", DriverDeprecated, override=True)

    return {
        'version': '0.1',
        'parallel_read_safe': True,
        'parallel_write_safe': True,
    }
