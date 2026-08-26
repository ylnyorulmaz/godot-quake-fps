# 3D modeller

Arenadaki botlar bu klasördeki ilk bulunan GLB’yi yükler. Şu an beklenen dosya:

```
assets/models/warrior.glb
```

## Sketchfab (önerilen)

[Low poly Warrior](https://sketchfab.com/3d-models/low-poly-warrior-3d-model-free-fa42852a8e314dfd932ebc294d32414f) — CC Attribution, ~19k üçgen.

1. Sketchfab’a ücretsiz giriş yap.
2. **Download 3D Model** → **GLB** (veya glTF zip; zip ise içindeki `.glb` / `scene.gltf` kullan).
3. Dosyayı `assets/models/warrior.glb` olarak kaydet.
4. Godot 4.7.2 Import dock bitince **F5**.

Lisans gereği kredi: `CREDITS.md`.

Yön tersse `EnemyBot` → **Model Yaw Degrees** (varsayılan 180). Boy `target_height` 1.8 m; çarpışma kapsülde kalır.

## Alternatif isimler

Sıra: Inspector `model_scene` → `model_path` → `warrior.glb` → `warrior.gltf` → `orc.glb` / `orc.gltf`.
