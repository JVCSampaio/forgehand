"""MakeHuman base bodies through MPFB2 (headless).

MPFB2 (makehumancommunity/mpfb2, code GPL, assets CC0) provides the base mesh,
the anatomical targets, the game_engine rig with weights and the eyes. It is a
build-time tool only: nothing of its code ships with the game.

Setup (once per machine):
    git clone --depth 1 https://github.com/makehumancommunity/mpfb2
    ln -s $PWD/mpfb2/src/mpfb ~/.config/blender/4.2/extensions/user_default/mpfb
    git clone --depth 1 --filter=blob:none --sparse https://github.com/makehumancommunity/makehuman
    (cd makehuman && git sparse-checkout set makehuman/data)
Set MH_DATA to makehuman/makehuman/data (for the eyes).
"""
import os
import sys

import bpy
import numpy as np

MH_DATA = os.environ.get('MH_DATA', '')


def mpfb():
    import addon_utils
    if 'bl_ext.user_default.mpfb' not in sys.modules:
        addon_utils.enable('bl_ext.user_default.mpfb', default_set=True, persistent=True)
    return lambda name: sys.modules['bl_ext.user_default.mpfb.' + name]


def create(macros, targets=None, rig='game_engine', eyes=True):
    """Create a rigged MakeHuman. macros: gender/age/muscle/weight/proportions/height/cupsize/firmness
    plus race dict. targets: {target_name: value} detail targets (e.g. 'nose-hump-incr')."""
    M = mpfb()
    HumanService = M('services.humanservice').HumanService
    TargetService = M('services.targetservice').TargetService
    info = TargetService.get_default_macro_info_dict()
    for k, v in macros.items():
        if k == 'race':
            info['race'].update(v)
        else:
            info[k] = v
    body = HumanService.create_human(macro_detail_dict=info)
    for name, val in (targets or {}).items():
        path = TargetService.target_full_path(name)
        if path is None:
            raise KeyError(name)
        TargetService.load_target(body, path, weight=val, name=name)
    if targets:
        # feet back on the ground after detail targets
        pass
    arm = HumanService.add_builtin_rig(body, rig) if rig else None
    eye_obj = None
    if eyes and MH_DATA:
        before = set(bpy.data.objects)
        res = HumanService.add_mhclo_asset(os.path.join(MH_DATA, 'eyes', 'high-poly', 'high-poly.mhclo'), body,
                                           asset_type='Eyes', subdiv_levels=0, material_type='NONE')
        eye_obj = res if isinstance(res, bpy.types.Object) else next(
            (o for o in bpy.data.objects if o not in before and o.type == 'MESH'), None)
    return body, arm, eye_obj


def mesh_arrays(obj, apply_modifiers=True, exclude=('Armature',)):
    """World-space vertices/faces of the evaluated object (shape keys and mask applied, armature not)."""
    saved = {}
    for m in obj.modifiers:
        if m.type in [e.upper() for e in exclude] or m.name in exclude:
            saved[m.name] = m.show_viewport
            m.show_viewport = False
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    v = np.array([vv.co[:] for vv in me.vertices], dtype=np.float32)
    M = np.array(obj.matrix_world)
    v = v @ M[:3, :3].T + M[:3, 3]
    polys = [p.vertices[:] for p in me.polygons]
    uv = None
    if me.uv_layers.active:
        uvl = me.uv_layers.active.data
        uv = [[uvl[li].uv[:] for li in p.loop_indices] for p in me.polygons]
    ev.to_mesh_clear()
    for n, s in saved.items():
        obj.modifiers[n].show_viewport = s
    return v, polys, uv
