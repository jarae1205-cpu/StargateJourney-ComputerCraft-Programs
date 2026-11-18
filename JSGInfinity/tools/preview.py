"""
Renders the pack's textures on JSG's own gate models, to check how they sit on the gate
without starting the game. A small software renderer: flat lighting, no Minecraft shaders.

    python3 preview.py <jsg jar> <pack dir> <out.png> [idle|open] [width]

The wormhole is drawn with a light blue tint; in the game JSG colours it itself. The iris
isn't drawn: JSG swings each blade in from the rim with its own animation.
"""
import math
import sys
import zipfile

import numpy as np
from PIL import Image

from make_pack import Model, MODELS, TESR

Image.MAX_IMAGE_PIXELS = None


def texture(pack, rel):
    im = Image.open(f"{pack}/{rel}").convert("RGBA")
    return np.asarray(im, dtype=np.float32) / 255.0


def rot_z(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])


class Canvas:
    def __init__(self, w, h, scale, yaw=-18, pitch=8):
        self.w, self.h, self.scale = w, h, scale
        self.color = np.zeros((h, w, 3), dtype=np.float32)
        self.color[:] = (0.80, 0.86, 0.93)
        self.depth = np.full((h, w), -1e9, dtype=np.float32)
        y, p = math.radians(yaw), math.radians(pitch)
        ry = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
        rx = np.array([[1, 0, 0], [0, math.cos(p), -math.sin(p)], [0, math.sin(p), math.cos(p)]])
        self.view = rx @ ry
        self.light = np.array([-0.35, 0.55, 0.76])
        self.light /= np.linalg.norm(self.light)

    def project(self, pts):
        q = pts @ self.view.T
        return np.stack([self.w / 2 + q[:, 0] * self.scale, self.h / 2 - q[:, 1] * self.scale, q[:, 2]], axis=1)

    def draw(self, model, tex, xform=np.eye(3), alpha_cut=0.5, emissive=False):
        th, tw = tex.shape[:2]
        v = model.v @ xform.T
        scr = self.project(v)
        normals = model.normals @ xform.T @ self.view.T
        for fi, f in enumerate(model.faces):
            n = normals[fi]
            shade = 1.0 if emissive else 0.62 + 0.38 * abs(float(np.dot(model.normals[fi] @ xform.T, self.light)))
            idx = [i for i, _ in f]
            uvs = model.vt[[t for _, t in f]]
            for k in range(1, len(f) - 1):
                tri = scr[[idx[0], idx[k], idx[k + 1]]]
                uv = uvs[[0, k, k + 1]]
                x0, y0 = np.floor(tri[:, :2].min(axis=0)).astype(int)
                x1, y1 = np.ceil(tri[:, :2].max(axis=0)).astype(int)
                x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, self.w - 1), min(y1, self.h - 1)
                if x1 < x0 or y1 < y0:
                    continue
                ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1] + 0.5
                (ax, ay, az), (bx, by, bz), (cx, cy, cz) = tri
                det = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
                if abs(det) < 1e-12:
                    continue
                l1 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / det
                l2 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / det
                l3 = 1 - l1 - l2
                inside = (l1 >= 0) & (l2 >= 0) & (l3 >= 0)
                if not inside.any():
                    continue
                z = l1 * az + l2 * bz + l3 * cz
                yi = (ys - 0.5).astype(int)
                xi = (xs - 0.5).astype(int)
                vis = inside & (z > self.depth[yi, xi])
                if not vis.any():
                    continue
                u = (l1 * uv[0, 0] + l2 * uv[1, 0] + l3 * uv[2, 0])[vis] % 1.0
                vv = (l1 * uv[0, 1] + l2 * uv[1, 1] + l3 * uv[2, 1])[vis] % 1.0
                tx = np.clip((u * tw).astype(int), 0, tw - 1)
                ty = np.clip(((1 - vv) * th).astype(int), 0, th - 1)
                c = tex[ty, tx]
                keep = c[:, 3] >= alpha_cut
                Y, X = yi[vis][keep], xi[vis][keep]
                self.color[Y, X] = c[keep, :3] * shade
                self.depth[Y, X] = z[vis][keep]

    def disc(self, radius, z, frame_fn, tint):
        """The event horizon: a flat disc textured with one frame of the sheet."""
        ys, xs = np.mgrid[0:self.h, 0:self.w] + 0.5
        # invert the projection for points on the plane z = const (orthographic)
        inv = self.view.T
        sx = (xs - self.w / 2) / self.scale
        sy = -(ys - self.h / 2) / self.scale
        # world point p with view @ p = (sx, sy, d); solve for d so that p.z = z
        a = inv[2, 0] * sx + inv[2, 1] * sy
        d = (z - a) / inv[2, 2]
        px = inv[0, 0] * sx + inv[0, 1] * sy + inv[0, 2] * d
        py = inv[1, 0] * sx + inv[1, 1] * sy + inv[1, 2] * d
        inside = np.hypot(px, py) <= radius
        depth = d
        vis = inside & (depth > self.depth)
        val = frame_fn(px[vis] / radius, py[vis] / radius)
        self.color[vis] = val[:, None] * np.array(tint)
        self.depth[vis] = depth[vis]

    def image(self):
        return Image.fromarray(np.clip(self.color * 255 + 0.5, 0, 255).astype(np.uint8), "RGB")


def sheet_sampler(path, frame):
    im = Image.open(path).convert("L")
    cell = im.size[0] / 14
    x, y = (frame % 14) * cell, (frame // 14) * cell
    f = np.asarray(im.crop((int(x), int(y), int(x + cell), int(y + cell))), dtype=np.float32) / 255.0
    n = f.shape[0]

    def sample(u, v):
        tx = np.clip(((u + 1) / 2 * (n - 1)).astype(int), 0, n - 1)
        ty = np.clip(((1 - (v + 1) / 2) * (n - 1)).astype(int), 0, n - 1)
        return f[ty, tx]
    return sample


def render(jar_path, pack, out, mode="open", width=900):
    jar = zipfile.ZipFile(jar_path)
    load = lambda p: Model(jar.read(MODELS + p).decode("utf-8", "replace"))
    mw = TESR + "milkyway/"
    ring_tex = texture(pack, mw + "gatering.jpg")
    chev = texture(pack, mw + "chevron.png")
    lit = texture(pack, mw + "chevron_light.png")
    unlit = texture(pack, mw + "chevron_light_off.png")
    cv = Canvas(width, width, width / 11.6)
    cv.draw(load("milkyway/gate.obj"), ring_tex)
    cv.draw(load("milkyway/ring.obj"), ring_tex, rot_z(0 if mode == "idle" else 27.7))
    parts = [load("milkyway/" + p) for p in ("chevron_frame.obj", "chevron_back.obj", "chevron_moving.obj")]
    light = load("milkyway/chevron_light.obj")
    for k in range(9):
        r = rot_z(-40 * k)
        for p in parts:
            cv.draw(p, chev, r)
        on = mode != "idle" and k not in (4, 5)  # seven chevrons lock; the two lowest stay dark
        cv.draw(light, lit if on else unlit, r, emissive=on)
    if mode == "open":
        cv.disc(4.0, 0.12, sheet_sampler(f"{pack}/{TESR}event_horizon_animated_template.jpg", 40), (0.62, 0.80, 1.0))
    cv.image().save(out)


if __name__ == "__main__":
    render(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "open",
           int(sys.argv[5]) if len(sys.argv) > 5 else 900)
