import streamlit as st
import numpy as np
import joblib
from tensorflow.keras.models import load_model
import os

# ==========================================
# 1. إعدادات الصفحة
# ==========================================
st.set_page_config(page_title="Robot IK Control", page_icon="🤖")

st.title("🤖 Robot Inverse Kinematics AI")
st.write("أدخل إحداثيات الهدف (Target) للحصول على زوايا المفاصل (Joint Angles) باستخدام الذكاء الاصطناعي.")

# ==========================================
# 2. تحميل الموديل والملفات (يتم تحميلها مرة واحدة فقط)
# ==========================================
@st.cache_resource
def load_ai_model():
    # أسماء الملفات (تأكد أنها بجانب الكود)
    model_path = 'Final_Robot_Model.keras'
    scaler_x_path = 'scaler_X.pkl'
    scaler_y_path = 'scaler_y.pkl'

    if not os.path.exists(model_path):
        st.error("❌ ملف الموديل غير موجود!")
        return None, None, None
    
    model = load_model(model_path)
    scaler_x = joblib.load(scaler_x_path)
    scaler_y = joblib.load(scaler_y_path)
    return model, scaler_x, scaler_y

model, scaler_X, scaler_Y = load_ai_model()

# ==========================================
# 3. دالة التوقع (نفس المنطق الرياضي)
# ==========================================
def predict_angles(x, y, z, roll, pitch, yaw):
    # Feature Engineering
    r_dist = np.sqrt(x**2 + y**2 + z**2)
    r_xy = np.sqrt(x**2 + y**2)
    
    rad_r, rad_p, rad_y = np.radians([roll, pitch, yaw])
    
    features = np.array([[
        x, y, z, r_dist, r_xy,
        np.sin(rad_r), np.cos(rad_r),
        np.sin(rad_p), np.cos(rad_p),
        np.sin(rad_y), np.cos(rad_y)
    ]])
    
    features_scaled = scaler_X.transform(features)
    pred_scaled = model.predict(features_scaled, verbose=0)
    return scaler_Y.inverse_transform(pred_scaled)[0]

# ==========================================
# 4. واجهة المستخدم (Inputs)
# ==========================================
st.sidebar.header("إحداثيات الهدف (Target Input)")

# تقسيم المدخلات لعمودين لشكل أجمل
col1, col2 = st.sidebar.columns(2)

with col1:
    x_val = st.number_input("X Position", value=37.0)
    y_val = st.number_input("Y Position", value=29.0)
    z_val = st.number_input("Z Position", value=418.0)

with col2:
    r_val = st.number_input("Roll (°)", value=-34.0)
    p_val = st.number_input("Pitch (°)", value=-7.0)
    yw_val = st.number_input("Yaw (°)", value=40.0)

# زر التشغيل
if st.sidebar.button("احسب الزوايا (Calculate)", type="primary"):
    if model is not None:
        with st.spinner('جاري الحساب...'):
            angles = predict_angles(x_val, y_val, z_val, r_val, p_val, yw_val)
        
        # عرض النتائج بشكل جميل
        st.success("✅ تم الحساب بنجاح!")
        st.subheader("الزوايا المطلوبة للمفاصل (Joint Angles):")
        
        # عرض النتائج في أعمدة
        cols = st.columns(5)
        labels = ['Q1', 'Q2', 'Q3', 'Q4', 'Q5']
        
        for i, col in enumerate(cols):
            col.metric(label=labels[i], value=f"{angles[i]:.2f}°")
            
        # عرض البيانات الخام
        st.info(f"📍 Target: X={x_val}, Y={y_val}, Z={z_val}")
    else:
        st.error("لا يمكن الحساب لعدم وجود ملفات الموديل.")

# تذييل الصفحة
st.markdown("---")
st.caption("Developed using TensorFlow & Streamlit for Robot Control Project.")