#!/usr/bin/env python3
"""Exercise the GTK viewer with a standalone SFBR producer on a Linux display."""
import importlib.util
import os
from pathlib import Path
import socket
import struct
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
WIDTH, HEIGHT = 96, 64
STRIDE = 4 * WIDTH


def publish(path, bgra):
    """Install a fresh ring inode with sequence one and two pixel slots."""
    size = HEIGHT * STRIDE
    frame = bytearray(4096 + 2 * size)
    struct.pack_into("<4s6I", frame, 0, b"SFBR", 2, 2, size, WIDTH, HEIGHT, STRIDE)
    struct.pack_into("<QI", frame, 32, 1, 1)
    struct.pack_into("<QQIII", frame, 96, 1, time.time_ns(), WIDTH, HEIGHT, STRIDE)
    frame[4096 + size:] = bgra * (WIDTH * HEIGHT)
    tmp = path.with_suffix(".new")
    tmp.write_bytes(frame)
    tmp.replace(path)


def find_picture(widget, Gtk):
    if isinstance(widget, Gtk.Picture):
        return widget
    child = widget.get_first_child()
    while child:
        result = find_picture(child, Gtk)
        if result is not None:
            return result
        child = child.get_next_sibling()


def controller(widget, kind):
    items = widget.observe_controllers()
    return next(item for item in items if isinstance(item, kind))


def run(directory, listener):
    path, sock = directory / "screen.ring", directory / "input.sock"
    listener.bind(str(sock))
    listener.listen()
    listener.settimeout(2)
    blue, red = b"\xff\x00\x00\xff", b"\x00\x00\xff\xff"
    publish(path, blue)
    sys.argv = [str(ROOT / "cli/libexec/simview.py"), "--external-ring", str(path), "--input-socket", str(sock)]
    os.environ["SIMFB_RING_LINUX"] = str(directory / "other.ring")
    os.environ["SIMHID_SOCKET"] = str(directory / "other.sock")
    spec = importlib.util.spec_from_file_location("simview", sys.argv[0])
    viewer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(viewer)
    Gtk, Gdk, GLib = viewer.Gtk, viewer.Gdk, viewer.GLib
    assert viewer.app.register(None)
    viewer.app.activate()
    win = viewer.app.get_active_window()
    pic = find_picture(win, Gtk)
    context = GLib.MainContext.default()

    def wait(check, what):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            while context.pending():
                context.iteration(False)
            if check():
                return
            time.sleep(0.02)
        raise AssertionError(what)

    def png(color):
        texture = Gdk.MemoryTexture.new(WIDTH, HEIGHT, Gdk.MemoryFormat.B8G8R8A8_PREMULTIPLIED,
                                        GLib.Bytes.new(color * (WIDTH * HEIGHT)), STRIDE)
        return texture.save_to_png_bytes().get_data()

    def picture_is(color):
        expected = png(color)
        return lambda: pic.get_paintable() is not None and pic.get_paintable().save_to_png_bytes().get_data() == expected

    wait(picture_is(blue), "GTK did not display the first frame")
    keys = controller(win, Gtk.EventControllerKey)
    keys.emit("key-pressed", Gdk.KEY_a, 0, Gdk.ModifierType(0))
    keys.emit("key-released", Gdk.KEY_a, 0, Gdk.ModifierType(0))
    drag = controller(pic, Gtk.GestureDrag)
    drag.emit("drag-begin", pic.get_width() / 2, pic.get_height() / 2)
    drag.emit("drag-end", 0.0, 0.0)
    with listener.accept()[0] as client, client.makefile("rb") as lines:
        client.settimeout(2)
        commands = [lines.readline().decode().strip() for _ in range(5)]
    assert commands == ["kbidle 300", "key down 4", "key up 4", "touch down 0.50000 0.50000",
                        "touch up 0.50000 0.50000"], commands

    path.unlink()
    wait(lambda: "Off" in win.get_title(), "removed ring still displayed")
    publish(path, red)
    wait(picture_is(red), "GTK discarded sequence one on a new ring inode")
    win.close()
    print("PASS external GTK ring: displayed both pixel patterns, forwarded key and pointer, cleared on unlink")


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as temp, socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener:
        run(Path(temp), listener)
