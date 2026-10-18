"""Seen from above: the demons' overworld sprites drawn for the 3D camera, like
the hero (make_hero_tilt.py) -- not at eye level.

The designs in overworld_demons.py are drawn as if you stood in front of them:
face in the middle of the head, the body at full height. The 3D view looks
down on them, so here every drawing call goes through TiltSprite, which moves
the design's coordinates the way the camera would see them:
  - below the shoulders the body is foreshortened (BODY_K): shorter robes,
    legs tucked under, the feet on the ground where they were
  - the head keeps its size (it sits nearer the camera) and moves down with
    the shortened body
  - the face slides toward the bottom of the head (FACE_K) so the crown of
    the hood or skull shows above it
  - light comes from above (pixkit.LIGHT, set while the demons are drawn)
The designs themselves -- shapes, colours, the way each one moves -- don't
change. make_overworld_creatures.py draws the demons through this.
"""
import pixkit

GROUND = 30
BODY_K = 0.78       # how much of its height the body below the shoulders keeps
FACE_K = 0.62       # face features: their distance from the bottom of the head, kept
TOP_LIGHT = (-0.42, -0.86, 0.40)
FACE_MATS = {"mouth", "teeth", "gum", "tongue", "tear"}

# per design: the shoulder line and the head (top, bottom) in the design's own
# coordinates (frames' bob aside); a blob design has no neck: its whole body is "head"
PARAMS = {
    "grinner":    dict(shoulder=13.5, head=(3.0, 14.8)),
    "many_eyes":  dict(shoulder=11.0, head=(10.0, 29.0), body_k=0.88, face_k=0.9),   # (eyes all over: keep them spread)
    "wraith":     dict(shoulder=12.5, head=(3.5, 12.0)),
    "hollow":     dict(shoulder=13.5, head=(4.6, 13.2)),
    "maw":        dict(shoulder=9.0, head=(8.0, 29.0), body_k=0.88),
    "weeper":     dict(shoulder=12.0, head=(4.2, 11.6)),
    "bride":      dict(shoulder=12.0, head=(4.2, 11.6)),
    "marionette": dict(shoulder=12.0, head=(4.2, 11.8)),
    "witch":      dict(shoulder=13.0, head=(5.0, 13.0)),
    "shepherd":   dict(shoulder=10.5, head=(2.0, 11.0)),
}


class TiltSprite:
    """Wraps a pixkit.Sprite; the design draws on it exactly as before."""

    def __init__(self, sprite, design):
        self.s = sprite
        p = PARAMS[design]
        self.sh = p["shoulder"]
        self.k = p.get("body_k", BODY_K)
        self.top, self.bot = p["head"]
        self.face_k = p.get("face_k", FACE_K)

    def __getattr__(self, name):
        return getattr(self.s, name)

    # --- the camera ---
    def y(self, y):
        h = GROUND - y
        hs = GROUND - self.sh
        h2 = h * self.k if h <= hs else hs * self.k + (h - hs)
        return GROUND - h2

    def dy(self, y):
        return self.k if y > self.sh else 1.0

    def face(self, y):
        if self.top <= y <= self.bot + 1.0:
            return self.bot - (self.bot - y) * self.face_k
        return y

    def is_face(self, mat, small=True):
        return mat in FACE_MATS or (isinstance(mat, str) and mat not in pixkit_mats() and len(mat) == 6) \
            or (mat in ("bone", "skin") and small)

    def pt(self, x, y, mat, small=False):
        if self.is_face(mat, small):
            y = self.face(y)
        return x, self.y(y)

    # --- the drawing calls the designs use ---
    def blob(self, cx, cy, rx, ry, mat, *a, **kw):
        small = max(rx, ry) <= 2.6
        x, y = self.pt(cx, cy, mat, small)
        return self.s.blob(x, y, rx, ry * self.dy(cy), mat, *a, **kw)

    def limb(self, pts, r, mat, *a, **kw):
        return self.s.limb([(x, self.y(y)) for x, y in pts], r, mat, *a, **kw)

    def poly(self, pts, mat, *a, **kw):
        return self.s.poly([(x, self.y(y)) for x, y in pts], mat, *a, **kw)

    def dot(self, x, y, mat, *a, **kw):
        x2, y2 = self.pt(x, y, mat, True)
        return self.s.dot(x2, round(y2), mat, *a, **kw)

    def line(self, pts, mat, *a, **kw):
        return self.s.line([self.pt(x, y, mat, True) for x, y in pts], mat, *a, **kw)


_MATS = None


def pixkit_mats():
    """Material names (not hex colours) the demon palettes use."""
    global _MATS
    if _MATS is None:
        _MATS = {"cloak", "skin", "bone", "claw", "mouth", "teeth", "gum", "tongue", "tear", "hair", "veil",
                 "flower", "gold", "wood", "string", "glow", "wax"}
    return _MATS


class top_light:
    """with top_light(): ... -- pixkit lights from above while the demons are drawn."""

    def __enter__(self):
        self.old = pixkit.LIGHT
        import math
        n = math.sqrt(sum(c * c for c in TOP_LIGHT))
        pixkit.LIGHT = tuple(c / n for c in TOP_LIGHT)

    def __exit__(self, *e):
        pixkit.LIGHT = self.old
