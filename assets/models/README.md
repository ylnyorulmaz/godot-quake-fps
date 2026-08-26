# 3D modeller (Tripo → Godot)

Tripo Studio’dan indirdiğin **GLB** dosyasını buraya koy. Arenadaki botlar otomatik yükler.

1. [studio.tripo3d.ai](https://studio.tripo3d.ai/) içinde orc’u üret, **GLB** olarak indir (dokular dosyanın içinde olsun).
2. Dosyayı şu isimle kaydet: `assets/models/orc.glb`
3. Godot 4.7.2’de projeyi aç, Import dock bitene kadar bekle, **F5**.

Yön tersse `EnemyBot` üzerinde **Model Yaw Degrees** (varsayılan 180). Boy, `target_height` (1.8 m) olacak şekilde ölçeklenir; çarpışma mevcut kapsülde kalır.

---

Drop a **glTF Binary** (`.glb`) here. Arena bots load it automatically.

## Tripo Studio

1. Open [studio.tripo3d.ai](https://studio.tripo3d.ai/) and generate the orc.
2. Prefer **GLB** export (textures baked in). FBX/OBJ also work after re-export, but GLB is the Godot-native path.
3. Save the file as:

```
assets/models/orc.glb
```

4. In Godot: wait until the Import dock finishes (a `.glb.import` file appears next to it). Then press **F5**.

The first bot visual that exists wins, in this order:

- Inspector `model_scene` on `EnemyBot`
- Inspector `model_path` (default `res://assets/models/orc.glb`)
- Fallback names: `orc.gltf`, `orc.tscn`, `Orc.glb`

Placeholder capsules hide when a file is found. Collision stays the existing 1.8 m capsule — do not import physics from the GLB.

## If the orc faces the wrong way

On `EnemyBot`, set **Model Yaw Degrees**. Tripo/Blender meshes often face +Z; Godot characters look down **−Z**, so the default is **180**.

If the model is huge or tiny, leave `target_height` at `1.8` — the loader scales uniformly to that height and plants the feet on the floor.

## Optional: Tripo Godot Bridge

Tripo also ships a DCC bridge that pushes a mesh straight into the editor. After it lands under `res://`, point `model_path` at that file or rename it to `orc.glb`.
