"""
Model definitions for the DARM inference backend.

`GrandmasterFusionNet` is copied VERBATIM from the training notebook
(notebookda8f63fb86 / notebook917bb6d0fa) so the exported fusion state_dict
(EMA) loads with strict=True.

`BackboneBank` reproduces the FIVE feature extractors exactly as the Kaggle
notebooks built them — all with **torchvision.models** (NOT timm), 448x448 input,
ImageNet normalization, classification head stripped:

  Swin        : swin_t              -> head = Identity           -> 768
  ConvNeXt    : convnext_base       -> classifier[2] = Identity  -> 1024
  EfficientNet: efficientnet_b4     -> classifier = Identity     -> 1792
  DenseNet    : densenet201         -> classifier = Identity     -> 1920
  ResNet/unet : UNetSkipFinetuner   -> GAP(layer1,2,3) 64+128+256-> 448

Sources:
  swin      = notebookb1b39e541b   convnext = notebook8918449425
  resnet    = notebook61f9b81138   effnet   = notebook50ed648745
  densenet  = notebookedc4a7778e
"""
from __future__ import annotations

import torch
import torch.nn as nn


# ===========================================================================
# Fusion head - VERBATIM from the notebooks (full C2 config)
# ===========================================================================
class GrandmasterFusionNet(nn.Module):
    def __init__(self):
        super().__init__()
        self.swin_norm = nn.LayerNorm(768)
        self.conv_norm = nn.LayerNorm(1024)
        self.eff_norm = nn.LayerNorm(1792)
        self.dense_norm = nn.LayerNorm(1920)

        self.unet_norm = nn.LayerNorm(448)
        self.unet_bottleneck = nn.Sequential(
            nn.Linear(448, 128), nn.Tanh(), nn.Dropout(0.3)
        )

        self.loc_emb = nn.Embedding(15, 16)
        self.sex_emb = nn.Embedding(3, 8)
        self.meta_mlp = nn.Sequential(
            nn.Linear(16 + 8 + 1, 128), nn.GELU(), nn.LayerNorm(128)
        )

        self.fusion_head = nn.Sequential(
            nn.Linear(5760, 1024), nn.LayerNorm(1024), nn.GELU(), nn.Dropout(0.4),
            nn.Linear(1024, 256), nn.LayerNorm(256), nn.GELU(), nn.Dropout(0.3),
            nn.Linear(256, 7),
        )

    def forward(self, swin, conv, eff, dense, unet, loc, sex, age):
        s_feat, c_feat = self.swin_norm(swin), self.conv_norm(conv)
        e_feat, d_feat = self.eff_norm(eff), self.dense_norm(dense)
        u_feat = self.unet_bottleneck(self.unet_norm(unet))

        m_concat = torch.cat(
            [self.loc_emb(loc), self.sex_emb(sex), age.unsqueeze(1)], dim=1
        )
        m_feat = self.meta_mlp(m_concat)

        unified_vector = torch.cat([s_feat, c_feat, e_feat, d_feat, u_feat, m_feat], dim=1)
        return self.fusion_head(unified_vector)


# ===========================================================================
# ResNet-34 multi-scale branch ("unet") - VERBATIM from notebook61f9b81138.
# Attribute names (stem/layer1/2/3/pool/classifier) are kept identical so the
# saved state_dict loads cleanly.
# ===========================================================================
class UNetSkipFinetuner(nn.Module):
    def __init__(self, num_classes: int = 7, pretrained: bool = False):
        super().__init__()
        from torchvision import models
        weights = models.ResNet34_Weights.DEFAULT if pretrained else None
        base = models.resnet34(weights=weights)
        self.stem = nn.Sequential(base.conv1, base.bn1, base.relu, base.maxpool)
        self.layer1 = base.layer1   # 64
        self.layer2 = base.layer2   # 128
        self.layer3 = base.layer3   # 256
        self.pool = nn.AdaptiveAvgPool2d((1, 1))
        self.classifier = nn.Linear(448, num_classes)

    def forward_features(self, x):
        x1 = self.layer1(self.stem(x))
        x2 = self.layer2(x1)
        x3 = self.layer3(x2)
        return torch.cat(
            [self.pool(x1).flatten(1), self.pool(x2).flatten(1), self.pool(x3).flatten(1)],
            dim=1,
        )  # (B, 448)

    def forward(self, x):
        return self.classifier(self.forward_features(x))


# ===========================================================================
# Backbone bank - the five torchvision extractors
# ===========================================================================
class BackboneBank(nn.Module):
    def __init__(self, pretrained: bool = False):
        super().__init__()
        from torchvision import models

        w = models.Swin_T_Weights.DEFAULT if pretrained else None
        self.swin = models.swin_t(weights=w)
        self.swin.head = nn.Identity()  # -> 768

        w = models.ConvNeXt_Base_Weights.DEFAULT if pretrained else None
        self.convnext = models.convnext_base(weights=w)
        self.convnext.classifier[2] = nn.Identity()  # keep LayerNorm2d+Flatten -> 1024

        w = models.EfficientNet_B4_Weights.DEFAULT if pretrained else None
        self.efficientnet = models.efficientnet_b4(weights=w)
        self.efficientnet.classifier = nn.Identity()  # -> 1792

        w = models.DenseNet201_Weights.DEFAULT if pretrained else None
        self.densenet = models.densenet201(weights=w)
        self.densenet.classifier = nn.Identity()  # -> 1920

        self.unet = UNetSkipFinetuner(num_classes=7, pretrained=pretrained)

    @torch.no_grad()
    def forward(self, x):
        return {
            "swin": self.swin(x),
            "convnext": self.convnext(x),
            "efficientnet": self.efficientnet(x),
            "densenet": self.densenet(x),
            "unet": self.unet.forward_features(x),
        }
