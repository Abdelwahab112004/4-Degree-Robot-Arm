import numpy as np
import joblib
import os
from tensorflow.keras.models import load_model

# =========================================================
# إعدادات المسارات (يفترض أن الملفات بجانب الكود مباشرة)
# =========================================================
model_path = 'Final_Robot_Model.keras'  # تأكد أن الاسم مطابق للملف الذي نزلته
scaler_x_path = 'scaler_X.pkl'
scaler_y_path = 'scaler_y.pkl'

print(">>> جاري تحميل النظام...")

# التحقق من وجود الملفات
if not (os.path.exists(model_path) and os.path.exists(scaler_x_path)):
    print("❌ خطأ: الملفات غير موجودة! تأكد أنك وضعت ملفات .keras و .pkl في نفس المجلد.")
    exit()

# 1. تحميل النموذج والـ Scalers
try:
    model = load_model(model_path)
    scaler_X = joblib.load(scaler_x_path)
    scaler_y = joblib.load(scaler_y_path)
    print("✅ تم تحميل الشبكة بنجاح. النظام جاهز!")
except Exception as e:
    print(f"حدث خطأ أثناء التحميل: {e}")
    exit()

# 2. دالة التوقع (نفس المنطق الرياضي الذي تدربت عليه الشبكة)
def get_joint_angles(x, y, z, roll, pitch, yaw):
    # أ) هندسة الميزات (Feature Engineering)
    r_dist = np.sqrt(x**2 + y**2 + z**2)
    r_xy = np.sqrt(x**2 + y**2)
    
    # تحويل الزوايا لراديان
    rad_r, rad_p, rad_y = np.radians([roll, pitch, yaw])
    
    # ب) تجهيز القائمة (11 مدخل)
    features = np.array([[
        x, y, z, r_dist, r_xy,
        np.sin(rad_r), np.cos(rad_r),
        np.sin(rad_p), np.cos(rad_p),
        np.sin(rad_y), np.cos(rad_y)
    ]])
    
    # ج) المعالجة والتوقع
    features_scaled = scaler_X.transform(features)
    prediction_scaled = model.predict(features_scaled, verbose=0)
    
    # د) إرجاع النتائج بالدرجات
    return scaler_y.inverse_transform(prediction_scaled)[0]

# =========================================================
# واجهة الاستخدام (تغيير القيم هنا)
# =========================================================
if __name__ == "__main__":
    while True:
        print("\n" + "="*30)
        print(" أدخل إحداثيات الهدف (أو اكتب 'q' للخروج)")
        print("="*30)
        
        try:
            val = input("أدخل القيم مفصولة بمسافة (X Y Z Roll Pitch Yaw): ")
            if val.lower() == 'q': break
            
            # قراءة المدخلات
            inputs = list(map(float, val.split()))
            
            if len(inputs) != 6:
                print("⚠️ خطأ: يجب إدخال 6 أرقام!")
                continue
                
            # تشغيل الشبكة
            x, y, z, r, p, yw = inputs
            angles = get_joint_angles(x, y, z, r, p, yw)
            
            print("\n--- النتائج (Joint Angles) ---")
            labels = ['Q1', 'Q2', 'Q3', 'Q4', 'Q5']
            for l, a in zip(labels, angles):
                print(f"{l}: {a:.2f}°")
                
        except ValueError:
            print("⚠️ خطأ: الرجاء إدخال أرقام صحيحة.")