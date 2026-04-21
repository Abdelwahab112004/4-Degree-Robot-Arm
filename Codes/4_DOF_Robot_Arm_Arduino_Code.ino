/*
 * RoboRash Professional - Arduino Firmware (Hardware Fix)
 * Updated to receive 6 angles from MATLAB
 */

#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>

Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver();

#define MIN_PWM 125
#define MAX_PWM 525
#define MIN_ANG -90.0
#define MAX_ANG 90.0

// تم زيادة المصفوفة لتشمل 6 دبابيس (0-5)
const int servoPins[6] = {0, 1, 2, 3, 4, 5}; 
float receivedAngles[6];
bool newData = false;

void setup() {
  Serial.begin(115200); 
  Serial.print("Ready");
  Serial.setTimeout(10); 

  pwm.begin();
  pwm.setPWMFreq(50);
  moveAllServos(0, 0, 0, 0, 0, 0); // Home لـ 6 مفاصل
}

void loop() {
  receiveData();
  if (newData) {
    // تمرير الزوايا الست إلى دالة الحركة
    moveAllServos(receivedAngles[0], 
                  receivedAngles[1], 
                  receivedAngles[2] * -1.0, // حفظ منطق الانعكاس الأصلي
                  receivedAngles[3], 
                  receivedAngles[4],
                  receivedAngles[5]);
    newData = false;
  }
}

void receiveData() {
  if (Serial.available() > 0) {
    char c = Serial.read();
    if (c == '<') {
      receivedAngles[0] = Serial.parseFloat();
      receivedAngles[1] = Serial.parseFloat();
      receivedAngles[2] = Serial.parseFloat();
      receivedAngles[3] = Serial.parseFloat();
      receivedAngles[4] = Serial.parseFloat();
      receivedAngles[5] = Serial.parseFloat(); // استقبال الزاوية السادسة
      Serial.readStringUntil('>');
      newData = true;
    }
  }
}

// تحديث الدالة لتستقبل 6 بارامترات
void moveAllServos(float q1, float q2, float q3, float q4, float q5, float q6) {
  setServoPulse(servoPins[0], q1);
  setServoPulse(servoPins[1], q2-5);
  setServoPulse(servoPins[2], -q3);
  setServoPulse(servoPins[3], q4);
  setServoPulse(servoPins[4], q5);
  setServoPulse(servoPins[5], q6); // تحريك الموتور السادس
}

void setServoPulse(uint8_t n, double angle) {
  if (angle < MIN_ANG) angle = MIN_ANG;
  if (angle > MAX_ANG) angle = MAX_ANG;
  double pulse = (angle - MIN_ANG) * (MAX_PWM - MIN_PWM) / (MAX_ANG - MIN_ANG) + MIN_PWM;
  pwm.setPWM(n, 0, int(pulse));
}
