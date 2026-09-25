"""Blender side of the pipeline: meshes, decimation, armatures, skinning,
materials, actions and glTF export. Runs on the `bpy` module (Blender 4.2)."""
import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Quaternion, Vector, Euler


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mesh_object(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts.tolist(), [], faces.tolist())
    me.validate()
    obj = link(bpy.data.objects.new(name, me))
    return obj


def decimate(verts, faces, target_tris, smooth=0):
    """Collapse-decimate a triangle soup to ~target_tris. Returns (verts, faces)."""
    obj = mesh_object('tmp_dec', verts, faces)
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        m = obj.modifiers.new('sm', 'SMOOTH')
        m.factor = 0.5
        m.iterations = smooth
    ratio = min(1.0, target_tris / max(1, len(me.polygons)))
    if ratio < 1.0:
        m = obj.modifiers.new('dec', 'DECIMATE')
        m.decimate_type = 'COLLAPSE'
        m.ratio = ratio
        m.use_collapse_triangulate = True
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me2 = bpy.data.meshes.new_from_object(ev)
    bm = bmesh.new()
    bm.from_mesh(me2)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(me2)
    bm.free()
    v = np.array([vv.co[:] for vv in me2.vertices], dtype=np.float32)
    f = np.array([p.vertices[:] for p in me2.polygons], dtype=np.int32)
    bpy.data.objects.remove(obj)
    bpy.data.meshes.remove(me)
    bpy.data.meshes.remove(me2)
    return v, f


def vertex_normals(v, f):
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    n = np.zeros_like(v)
    for i in range(3):
        np.add.at(n, f[:, i], fn)
    return n / (np.linalg.norm(n, axis=1, keepdims=True) + 1e-12)


_mats = {}


def material(name, color=(0.8, 0.8, 0.8), rough=0.8, metal=0.0, emissive=None, emit_strength=1.0, alpha=None):
    if name in _mats and _mats[name].name in bpy.data.materials:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    if emissive is not None:
        bsdf.inputs['Emission Color'].default_value = (*emissive, 1)
        bsdf.inputs['Emission Strength'].default_value = emit_strength
    # Vertex colour multiplies the base colour (exported as COLOR_0).
    vc = nt.nodes.new('ShaderNodeVertexColor')
    vc.layer_name = 'Col'
    mix = nt.nodes.new('ShaderNodeMix')
    mix.data_type = 'RGBA'
    mix.blend_type = 'MULTIPLY'
    mix.inputs['Factor'].default_value = 1.0
    mix.inputs['A'].default_value = (*color, 1)
    nt.links.new(vc.outputs['Color'], mix.inputs['B'])
    nt.links.new(mix.outputs['Result'], bsdf.inputs['Base Color'])
    _mats[name] = m
    return m


def build_mesh(name, v, f, mats, face_mat=None, colors=None, normals=None):
    """mats: list of bpy materials; face_mat: per-face index; colors: per-vertex RGB."""
    obj = mesh_object(name, v, f)
    me = obj.data
    for m in mats:
        me.materials.append(m)
    if face_mat is not None:
        me.polygons.foreach_set('material_index', face_mat.astype(np.int32))
    for p in me.polygons:
        p.use_smooth = True
    if colors is not None:
        attr = me.color_attributes.new('Col', 'BYTE_COLOR', 'POINT')
        rgba = np.concatenate([colors, np.ones((len(colors), 1))], axis=1).astype(np.float32)
        attr.data.foreach_set('color', rgba.ravel())
        me.color_attributes.active_color = attr
    if normals is not None:
        me.normals_split_custom_set_from_vertices(normals.tolist())
    me.update()
    return obj


def build_armature(name, J, bones):
    arm = bpy.data.armatures.new(name)
    obj = link(bpy.data.objects.new(name, arm))
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    eb = {}
    for (bn, parent, a, b) in bones:
        e = arm.edit_bones.new(bn)
        e.head = Vector(J[a])
        e.tail = Vector(J[b])
        if (e.tail - e.head).length < 1e-4:
            e.tail = e.head + Vector((0, 0, 0.05))
        # consistent roll: local Z towards the character's front (-Y) when possible
        d = (e.tail - e.head).normalized()
        e.align_roll(Vector((0, -1, 0)) if abs(d.y) < 0.9 else Vector((0, 0, 1)))
        if parent:
            e.parent = eb[parent]
            e.use_connect = False
        e.use_deform = bn != 'root'
        eb[bn] = e
    bpy.ops.object.mode_set(mode='OBJECT')
    return obj


def add_socket(arm_obj, name, bone, offset=(0, 0, 0), rot=(0, 0, 0)):
    """Empty parented to a bone. Location/rotation are in armature space."""
    e = link(bpy.data.objects.new(name, None))
    e.empty_display_size = 0.05
    e.parent = arm_obj
    e.parent_type = 'BONE'
    e.parent_bone = bone
    b = arm_obj.data.bones[bone]
    # parenting to a bone places the child at the bone's tail
    world = Matrix.Translation(Vector(offset)) @ Euler([np.radians(a) for a in rot]).to_matrix().to_4x4()
    tail = arm_obj.matrix_world @ Matrix.Translation(b.tail_local) @ b.matrix_local.to_3x3().to_4x4()
    e.matrix_parent_inverse = Matrix.Identity(4)
    e.matrix_basis = tail.inverted() @ world
    return e


def skin(obj, arm_obj, names, W):
    for j, n in enumerate(names):
        vg = obj.vertex_groups.new(name=n)
        nz = np.nonzero(W[:, j] > 0)[0]
        for i in nz:
            vg.add([int(i)], float(W[i, j]), 'REPLACE')
    obj.parent = arm_obj
    mod = obj.modifiers.new('Armature', 'ARMATURE')
    mod.object = arm_obj
    return obj


def rigid(obj, arm_obj, bone):
    vg = obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    obj.parent = arm_obj
    mod = obj.modifiers.new('Armature', 'ARMATURE')
    mod.object = arm_obj
    return obj


# ---------------------------------------------------------------- actions
def world_to_local_rot(bone, R):
    """Rotation R (3x3, armature-rest space, about the bone head) -> pose-local quaternion."""
    B = bone.matrix_local.to_3x3()
    q = (B.inverted() @ Matrix(R) @ B).to_quaternion()
    return q


def euler_R(x, y, z):
    return (Euler((np.radians(x), np.radians(y), np.radians(z)), 'XYZ')).to_matrix()


def make_action(arm_obj, name, keys, fps=30, loop=False):
    """keys: list of (frame, {bone: (rx, ry, rz) degrees in rest axes, 'hips@loc': (x,y,z)})."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm_obj.animation_data_create()
    arm_obj.animation_data.action = act
    pb = arm_obj.pose.bones
    bones = set()
    for _, pose in keys:
        bones |= {k.split('@')[0] for k in pose}
    for b in pb:
        b.rotation_mode = 'QUATERNION'
    for frame, pose in keys:
        for b in pb:
            b.rotation_quaternion = Quaternion()
            b.location = Vector()
        for k, val in pose.items():
            if k.endswith('@loc'):
                bn = k[:-4]
                bone = arm_obj.data.bones[bn]
                pb[bn].location = bone.matrix_local.to_3x3().inverted() @ Vector(val)
            else:
                bone = arm_obj.data.bones[k]
                pb[k].rotation_quaternion = world_to_local_rot(bone, euler_R(*val))
        for bn in bones:
            pb[bn].keyframe_insert('rotation_quaternion', frame=frame)
            pb[bn].keyframe_insert('location', frame=frame)
    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = 'BEZIER'
            kp.handle_left_type = kp.handle_right_type = 'AUTO_CLAMPED'
        if loop:
            m = fc.modifiers.new('CYCLES')
        fc.update()
    arm_obj.animation_data.action = None
    track = arm_obj.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, int(keys[0][0]), act)
    track.mute = True
    return act


def export_glb(path, objects=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in (objects or bpy.context.scene.objects):
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format='GLB', use_selection=objects is not None,
        export_vertex_color='ACTIVE', export_animation_mode='ACTIONS', export_skins=True,
        export_influence_nb=4, export_def_bones=False, export_yup=True, export_apply=False,
        export_force_sampling=True, export_optimize_animation_size=True, export_materials='EXPORT',
        export_anim_slide_to_zero=True, export_extras=True,
    )


def image(path, colorspace='sRGB'):
    img = bpy.data.images.load(path, check_existing=True)
    img.colorspace_settings.name = colorspace
    return img


def pbr_material(name, color=(1, 1, 1), base=None, normal=None, mr=None, rough=0.7, metal=0.0,
                 normal_strength=1.0, alpha_clip=None, emissive=None, emit_strength=1.0, double_sided=False,
                 vertex_color=False):
    """glTF-friendly Principled material. base/normal/mr are image paths; mr packs
    roughness in G and metallic in B. `color` becomes baseColorFactor (runtime tint)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = not double_sided
    nt = m.node_tree
    bsdf = nt.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    if base:
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = image(base, 'sRGB')
        src = tex.outputs['Color']
        if color != (1, 1, 1):
            mix = nt.nodes.new('ShaderNodeMix')
            mix.data_type = 'RGBA'
            mix.blend_type = 'MULTIPLY'
            mix.inputs['Factor'].default_value = 1.0
            nt.links.new(tex.outputs['Color'], mix.inputs['A'])
            mix.inputs['B'].default_value = (*color, 1)
            src = mix.outputs['Result']
        nt.links.new(src, bsdf.inputs['Base Color'])
        if alpha_clip is not None:
            nt.links.new(tex.outputs['Alpha'], bsdf.inputs['Alpha'])
            m.blend_method = 'CLIP'
            m.alpha_threshold = alpha_clip
    elif vertex_color:
        vc = nt.nodes.new('ShaderNodeVertexColor')
        vc.layer_name = 'Col'
        mix = nt.nodes.new('ShaderNodeMix')
        mix.data_type = 'RGBA'
        mix.blend_type = 'MULTIPLY'
        mix.inputs['Factor'].default_value = 1.0
        mix.inputs['A'].default_value = (*color, 1)
        nt.links.new(vc.outputs['Color'], mix.inputs['B'])
        nt.links.new(mix.outputs['Result'], bsdf.inputs['Base Color'])
    if normal:
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = image(normal, 'Non-Color')
        nm = nt.nodes.new('ShaderNodeNormalMap')
        nm.inputs['Strength'].default_value = normal_strength
        nt.links.new(tex.outputs['Color'], nm.inputs['Color'])
        nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    if mr:
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = image(mr, 'Non-Color')
        sep = nt.nodes.new('ShaderNodeSeparateColor')
        nt.links.new(tex.outputs['Color'], sep.inputs['Color'])
        nt.links.new(sep.outputs['Green'], bsdf.inputs['Roughness'])
        nt.links.new(sep.outputs['Blue'], bsdf.inputs['Metallic'])
    if emissive is not None:
        bsdf.inputs['Emission Color'].default_value = (*emissive, 1)
        bsdf.inputs['Emission Strength'].default_value = emit_strength
    return m


def obj_arrays(obj):
    """Rest-pose vertices (object space), normals, polygons and per-loop UVs."""
    me = obj.data
    v = np.array([x.co[:] for x in me.vertices], np.float32)
    n = np.array([x.normal[:] for x in me.vertices], np.float32)
    polys = [p.vertices[:] for p in me.polygons]
    uvl = me.uv_layers.active.data if me.uv_layers.active else None
    uvs = [[uvl[li].uv[:] for li in p.loop_indices] for p in me.polygons] if uvl else None
    return v, n, polys, uvs
