"""Character kit: a rigged MakeHuman base plus layered parts built from it.

Every part (body, eyes, brows, garments, hair) is a separate skinned mesh bound
to the same armature, the way Project Zomboid layers clothing on one body.
Parts are carved from the base mesh or from MakeHuman's fitting helpers
(helper-tights, helper-skirt, helper-hair), so their weights come straight from
the rig and they follow every deformation of the body.
"""
import numpy as np
import bpy
import bmesh

import bl
import mh


class Base:
    def __init__(self, macros, targets=None, rig='game_engine'):
        M = mh.mpfb()
        HS = M('services.humanservice').HumanService
        TS = M('services.targetservice').TargetService
        info = TS.get_default_macro_info_dict()
        for k, v in macros.items():
            if k == 'race':
                info['race'].update(v)
            else:
                info[k] = v
        body = HS.create_human(mask_helpers=False, macro_detail_dict=info)
        for name, val in (targets or {}).items():
            TS.load_target(body, TS.target_full_path(name), weight=val, name=name)
        self.arm = HS.add_builtin_rig(body, rig)
        eyes = None
        if mh.MH_DATA:
            import os
            before = set(bpy.data.objects)
            HS.add_mhclo_asset(os.path.join(mh.MH_DATA, 'eyes', 'high-poly', 'high-poly.mhclo'), body,
                               asset_type='Eyes', subdiv_levels=0, material_type='NONE')
            eyes = next((o for o in bpy.data.objects if o not in before and o.type == 'MESH'), None)
        TS.bake_targets(body)
        self.src = body
        me = body.data
        Mw = np.array(body.matrix_world)
        self.V = np.array([v.co[:] for v in me.vertices], np.float32) @ Mw[:3, :3].T + Mw[:3, 3]
        self.polys = [tuple(p.vertices) for p in me.polygons]
        uvl = me.uv_layers.active.data
        self.puv = [[tuple(uvl[li].uv) for li in p.loop_indices] for p in me.polygons]
        self.bones = [b.name for b in self.arm.data.bones if b.use_deform]
        bi = {n: i for i, n in enumerate(self.bones)}
        gi = {vg.index: vg.name for vg in body.vertex_groups}
        self.W = np.zeros((len(self.V), len(self.bones)), np.float32)
        self.groups = {}
        for v in me.vertices:
            for g in v.groups:
                name = gi[g.group]
                if name in bi:
                    self.W[v.index, bi[name]] = g.weight
                else:
                    self.groups.setdefault(name, []).append(v.index)
        self.groups = {k: np.array(v) for k, v in self.groups.items()}
        s = self.W.sum(1, keepdims=True)
        self.W = np.where(s > 0, self.W / np.maximum(s, 1e-9), 0)
        self.eyes = eyes
        B = self.arm.data.bones
        W = self.arm.matrix_world
        self.J = {b.name: np.array((W @ b.head_local)[:], np.float32) for b in B}
        self.Jt = {b.name: np.array((W @ b.tail_local)[:], np.float32) for b in B}
        # vertex normals of the base mesh
        me.calc_normals_split() if hasattr(me, 'calc_normals_split') else None
        self.N = np.array([v.normal[:] for v in me.vertices], np.float32) @ Mw[:3, :3].T
        self.N /= np.linalg.norm(self.N, axis=1, keepdims=True) + 1e-9

    def group_faces(self, group):
        ids = set(self.groups[group].tolist())
        return [i for i, p in enumerate(self.polys) if all(v in ids for v in p)]

    def face_centers(self, faces):
        return np.array([self.V[list(self.polys[f])].mean(0) for f in faces], np.float32)

    def dominant_bone(self, faces):
        out = []
        for f in faces:
            w = self.W[list(self.polys[f])].sum(0)
            out.append(self.bones[int(np.argmax(w))])
        return out

    def discard_source(self):
        bpy.data.objects.remove(self.src)


def part(base, name, faces, V=None, uv=True, weights=None):
    """Blender object from a subset of base polygons (V overrides positions)."""
    V = base.V if V is None else V
    used = sorted({v for f in faces for v in base.polys[f]})
    remap = {o: n for n, o in enumerate(used)}
    me = bpy.data.meshes.new(name)
    me.from_pydata(V[used].tolist(), [], [[remap[v] for v in base.polys[f]] for f in faces])
    if uv:
        lay = me.uv_layers.new(name='UVMap')
        k = 0
        for fi, f in enumerate(faces):
            for c in base.puv[f]:
                lay.data[k].uv = c
                k += 1
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    Wsub = (base.W if weights is None else weights)[used]
    for j, bn in enumerate(base.bones):
        col = Wsub[:, j]
        nz = np.nonzero(col > 1e-4)[0]
        if len(nz):
            vg = obj.vertex_groups.new(name=bn)
            for i in nz:
                vg.add([int(i)], float(col[i]), 'REPLACE')
    obj['base_ids'] = used
    return obj


def apply_mods(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    bpy.data.meshes.remove(old)
    return obj


def subdivide(obj, levels=1):
    m = obj.modifiers.new('sub', 'SUBSURF')
    m.levels = m.render_levels = levels
    m.uv_smooth = 'PRESERVE_CORNERS'
    return apply_mods(obj)


def solidify(obj, thickness, offset=-1.0, rim=True):
    m = obj.modifiers.new('sol', 'SOLIDIFY')
    m.thickness = thickness
    m.offset = offset
    m.use_rim = rim
    m.use_even_offset = True
    m.use_quality_normals = True
    return apply_mods(obj)


def coords(obj):
    return np.array([v.co[:] for v in obj.data.vertices], np.float32)


def normals(obj):
    obj.data.update()
    return np.array([v.normal[:] for v in obj.data.vertices], np.float32)


def set_coords(obj, V):
    obj.data.vertices.foreach_set('co', V.astype(np.float32).ravel())
    obj.data.update()


def weights_of(obj, bones):
    W = np.zeros((len(obj.data.vertices), len(bones)), np.float32)
    idx = {vg.index: bones.index(vg.name) for vg in obj.vertex_groups if vg.name in bones}
    for v in obj.data.vertices:
        for g in v.groups:
            if g.group in idx:
                W[v.index, idx[g.group]] = g.weight
    return W


def set_weights(obj, bones, W):
    obj.vertex_groups.clear()
    for j, bn in enumerate(bones):
        col = W[:, j]
        nz = np.nonzero(col > 1e-4)[0]
        if len(nz):
            vg = obj.vertex_groups.new(name=bn)
            for i in nz:
                vg.add([int(i)], float(col[i]), 'REPLACE')


def bind(obj, arm):
    obj.parent = arm
    m = obj.modifiers.new('Armature', 'ARMATURE')
    m.object = arm
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def smart_uv(obj, angle=66.0, margin=0.004):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=np.radians(angle), island_margin=margin, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.select_set(False)


def arrays(obj):
    me = obj.data
    V = coords(obj)
    N = normals(obj)
    polys = [tuple(p.vertices) for p in me.polygons]
    uvl = me.uv_layers.active.data
    puv = [[tuple(uvl[li].uv) for li in p.loop_indices] for p in me.polygons]
    return V, N, polys, puv
