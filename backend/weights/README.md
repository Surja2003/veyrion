# Model weights

Drop your trained checkpoints here. Until all six are present, the API runs in
**mock mode** (`"mock": true` in every response) so the app works during
development.

## ⚠️ Blocking gap for real inference (read this)

I audited all your Kaggle notebooks. **Only 2 of the 5 backbones actually saved
their fine-tuned weights.** Swin, ConvNeXt and ResNet/unet computed their EMA
weights into a `best_weights` variable but **never `torch.save`d them** — they
only exported the cached `.npy` features. Those features are enough to train the
fusion head, but **not** enough to run a fresh image through the backbone at
inference time.

So to leave mock mode you must re-run those 3 notebooks with one line added.

### Fix: add a save line, then re-run each notebook and download the `.pth`

| Notebook | Add this line (right after `model.load_state_dict(best_weights)`) |
|----------|---------------------------------------------------------------------|
| notebookb1b39e541b (Swin) | `torch.save(best_weights, '/kaggle/working/swin_best.pth')` |
| notebook8918449425 (ConvNeXt) | `torch.save(best_weights, '/kaggle/working/convnext_best.pth')` |
| notebook61f9b81138 (ResNet/unet) | `torch.save(best_weights, '/kaggle/working/unet_best.pth')` |

(`best_weights` is already `copy.deepcopy(ema_engine.ema.state_dict())` — the full
model EMA state dict. Saving it as-is is correct; the extractor ignores the
classification head via `strict=False`.)

## The files this backend expects

| File | What it is | Notebook |
|------|------------|----------|
| `best_teacher_ensemble.pth` _or_ `best_ema_model.pth` | Fusion head (EMA) | da8f63fb86 / 917bb6d0fa |
| `swin_best.pth` | Swin-Tiny (`torchvision.models.swin_t`, 768) | notebookb1b39e541b ⚠️ add save |
| `convnext_best.pth` | ConvNeXt-Base (`convnext_base`, 1024) | notebook8918449425 ⚠️ add save |
| `effnet_best.pth` | EfficientNet-B4 (`efficientnet_b4`, 1792) | notebook50ed648745 ✅ already saved |
| `densenet_best.pth` | DenseNet-201 (`densenet201`, 1920) | notebookedc4a7778e ✅ already saved |
| `unet_best.pth` | ResNet-34 multi-scale (`UNetSkipFinetuner`, 448) | notebook61f9b81138 ⚠️ add save |
| `age_normalization_stats.json` | `{"mean":…, "std":…}` | notebook2b05da16f1 (optional) |

## Verified inference contract (matches your notebooks exactly)
- **Backbones:** all `torchvision.models` (NOT timm), input **448×448**, `Normalize([0.485,0.456,0.406],[0.229,0.224,0.225])`.
- **Head stripping:** swin `head=Identity`; convnext `classifier[2]=Identity`; efficientnet `classifier=Identity`; densenet `classifier=Identity`; resnet = GAP over layer1/2/3 → 448.
- **Fusion head** loads with `strict=True`; **backbones** load with `strict=False` (so the leftover classification head in each checkpoint is ignored).

Weight files are git-ignored by default.
