import torch
import numpy as np

# Load the WPCA file and inspect its structure
print("Loading WPCA file...")
wpca_data = torch.load("/model-store/mapillary_WPCA128.pth.tar", map_location="cpu")

print(f"Type of loaded data: {type(wpca_data)}")

if isinstance(wpca_data, dict):
    print("Keys in WPCA data:")
    for key in wpca_data.keys():
        print(f"  {key}: {type(wpca_data[key])}")
        if hasattr(wpca_data[key], "shape"):
            print(f"    Shape: {wpca_data[key].shape}")
        elif hasattr(wpca_data[key], "__len__"):
            print(f"    Length: {len(wpca_data[key])}")
else:
    print(f"Direct tensor/array shape: {wpca_data.shape if hasattr(wpca_data, shape) else No
