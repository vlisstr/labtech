"""
New endpoint for experiment 5.

Add to spaceship/routers/api.py (or wherever the FastAPI router lives in
the starter project). The exact import paths depend on how the project
wires its router into the app.

The endpoint generates two 10x10 random matrices and returns them along
with their product:

    {
      "matrix_a": [[...], ...],
      "matrix_b": [[...], ...],
      "product":  [[...], ...]
    }
"""

import numpy as np


@router.get("/matrix")
def matrix_product():
    a = np.random.rand(10, 10)
    b = np.random.rand(10, 10)
    c = a @ b
    return {
        "matrix_a": a.tolist(),
        "matrix_b": b.tolist(),
        "product":  c.tolist(),
    }
