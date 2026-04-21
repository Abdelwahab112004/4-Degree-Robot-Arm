import numpy as np
import joblib
from tensorflow.keras.models import load_model
import math

# ===============================
# 1) Paths
# ===============================
MODEL_PATH = r"F:\Final_Robot_Model.keras"
SCALER_X_PATH = r"F:\scaler_X.pkl"
SCALER_Y_PATH = r"F:\scaler_y.pkl"

# ===============================
# 2) Load model & scalers
# ===============================
model = load_model(MODEL_PATH, compile=False)
scaler_X = joblib.load(SCALER_X_PATH)
scaler_y = joblib.load(SCALER_Y_PATH)

print("✅ Model and scalers loaded successfully!")

# ===============================
# 3) Input values (manual)
# ===============================
x = float(input("Enter X: "))
y = float(input("Enter Y: "))
z = float(input("Enter Z: "))
roll  = float(input("Enter Roll: "))
pitch = float(input("Enter Pitch: "))
yaw   = float(input("Enter Yaw: "))

# ===============================
# 4) Prepare input array
# ===============================
X_input = np.array([[x, y, z, roll, pitch, yaw]])

# ===============================
# 5) Scale input
# ===============================
X_scaled = scaler_X.transform(X_input)

# ===============================
# 6) Predict
# ===============================
y_pred_scaled = model.predict(X_scaled)

# ===============================
# 7) Inverse scaling to real angles
# ===============================
y_pred = scaler_y.inverse_transform(y_pred_scaled)

Q1_deg, Q2_deg, Q3_deg, Q4_deg, Q5_deg = y_pred[0]

# ===============================
# 8) Convert degrees to radians
# ===============================
def deg_to_rad(degrees):
    """Convert degrees to radians"""
    return degrees * math.pi / 180.0

Q1_rad = deg_to_rad(Q1_deg)
Q2_rad = deg_to_rad(Q2_deg)
Q3_rad = deg_to_rad(Q3_deg)
Q4_rad = deg_to_rad(Q4_deg)
Q5_rad = deg_to_rad(Q5_deg)

# ===============================
# 9) Print results
# ===============================
print("\n" + "="*50)
print("🔹 Predicted Joint Angles (Degrees):")
print("="*50)
print(f"Q1 = {Q1_deg:.3f}°")
print(f"Q2 = {Q2_deg:.3f}°")
print(f"Q3 = {Q3_deg:.3f}°")
print(f"Q4 = {Q4_deg:.3f}°")
print(f"Q5 = {Q5_deg:.3f}°")

print("\n" + "="*50)
print("🔹 Predicted Joint Angles (Radians):")
print("="*50)
print(f"Q1 = {Q1_rad:.6f} rad")
print(f"Q2 = {Q2_rad:.6f} rad")
print(f"Q3 = {Q3_rad:.6f} rad")
print(f"Q4 = {Q4_rad:.6f} rad")
print(f"Q5 = {Q5_rad:.6f} rad")
