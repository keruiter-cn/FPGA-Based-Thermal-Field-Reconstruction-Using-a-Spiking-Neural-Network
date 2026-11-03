import numpy as np
from matplotlib import colormaps, colors
from PyQt5.QtGui import QImage, QPixmap
from PyQt5.QtCore import Qt

def _to_numpy_2d(a):
    """支持 torch/numpy，返回 float32 的 2D numpy 数组；若 3D 则 squeeze 一下。"""
    if hasattr(a, "detach"):
        a = a.detach().cpu().numpy()
    a = np.asarray(a)
    if a.ndim == 3 and 1 in a.shape:
        a = np.squeeze(a)
    assert a.ndim == 2, f"期望2D数组，当前shape={a.shape}"
    a = a.astype(np.float32)
    # 避免 NaN/Inf 影响归一化
    a = np.nan_to_num(a, copy=False, nan=0.0, posinf=np.finfo(np.float32).max, neginf=np.finfo(np.float32).min)
    return a

def array_to_qpixmap_heatmap(arr, cmap_name='hot', vmin=None, vmax=None, origin='lower'):
    """
    将二维数值数组转为热力图 QPixmap。
    等价于 plt.imshow(arr, cmap=cmap_name, origin=origin, norm=Normalize(vmin, vmax)).
    """
    a = _to_numpy_2d(arr)

    # Matplotlib 的 origin='lower' 是把(0,0)放在左下角；QImage 从左上开始绘制，所以要上下翻转以对齐视觉效果
    if origin == 'lower':
        a = np.flipud(a)

    # 统一色域
    if vmin is None:
        vmin = float(np.min(a))
    if vmax is None:
        vmax = float(np.max(a))
    if vmin == vmax:
        # 避免全常量导致 Normalize 报错
        vmax = vmin + 1e-12

    norm = colors.Normalize(vmin=vmin, vmax=vmax, clip=True)
    cmap = colormaps[cmap_name]
    rgba = cmap(norm(a), bytes=True)  # (H, W, 4) uint8

    h, w, _ = rgba.shape
    # 注意：bytesPerLine=4*w（RGBA8888）
    qimg = QImage(rgba.data, w, h, 4 * w, QImage.Format_RGBA8888)
    qimg = qimg.copy()  # 深拷贝，防止 numpy 内存被回收
    return QPixmap.fromImage(qimg), vmin, vmax
