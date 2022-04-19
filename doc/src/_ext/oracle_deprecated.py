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
