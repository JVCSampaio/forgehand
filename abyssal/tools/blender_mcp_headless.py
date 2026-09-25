"""Run the MCP for Blender addon without a Blender GUI (cloud containers, CI).

The addon (ahujasid/mcp-for-blender) opens a socket server on localhost:9876 and
executes commands on Blender's main thread through bpy.app.timers, which never
fire when Blender is imported as the `bpy` Python module. This host loads the
addon, starts its server and drains the command queue itself, so the
`mcp-for-blender` MCP server (uvx mcp-for-blender) can drive a headless Blender.

    uvx mcp-for-blender install-addon --addons-dir ./.blender-addons
    python3 tools/blender_mcp_headless.py ./.blender-addons/blender_mcp.py

On a desktop, use the normal addon inside Blender instead.
"""
import importlib.util
import signal
import sys
import time

import bpy

path = sys.argv[1] if len(sys.argv) > 1 else 'blender_mcp.py'
src = open(path, encoding='utf-8').read()
# The addon refuses to start in background mode because timers never run there;
# this host runs the drain loop itself.
src = src.replace('if bpy.app.background:\n            print("BlenderMCP: cannot start server',
                  'if False:\n            print("BlenderMCP: cannot start server', 1)
spec = importlib.util.spec_from_loader('blender_mcp_headless_addon', loader=None)
mod = importlib.util.module_from_spec(spec)
mod.__file__ = path
exec(compile(src, path, 'exec'), mod.__dict__)

_orig_register = bpy.app.timers.register
bpy.app.timers.register = lambda *a, **k: None  # drained below instead

# Register the addon's scene properties and operators (its auto-start timer is a no-op here).
mod.register()

server = mod.BlenderMCPServer(host='localhost', port=int(sys.argv[2]) if len(sys.argv) > 2 else 9876)
server.start()
if not server.running:
    sys.exit('BlenderMCP server failed to start')
print('Headless BlenderMCP ready on localhost:%d (Blender %s)' % (server.port, bpy.app.version_string), flush=True)

stop = False


def _quit(*_):
    global stop
    stop = True


signal.signal(signal.SIGTERM, _quit)
signal.signal(signal.SIGINT, _quit)
while not stop:
    server._drain_command_queue()
    time.sleep(0.03)
server.stop()
