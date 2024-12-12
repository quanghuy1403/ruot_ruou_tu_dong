#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

#define VAL_SENSOR 33
#define RELAY_PIN 25
#define Mode_Button 14
#define Start_Button 18
#define POT_PIN 32 // Pin của biến trở B10K

LiquidCrystal_I2C lcd(0x27, 16, 2);

int sensorValue;
bool hasPoured = false;
const float flowRate = 12.25;

AsyncWebServer server(80);
AsyncWebSocket ws("/ws");
Preferences preferences;

const char* ssid = "ESP_RotRuou";
const char* password = "12345678";
IPAddress local_IP(192, 168, 4, 1);
IPAddress gateway(192, 168, 4, 1);
IPAddress subnet(255, 255, 255, 0);

bool isAutoMode = true;
bool isManualOn = false;
float mlAmount;
float lastB10KValue; // Biến lưu trữ giá trị cuối cùng từ B10K
bool lastButtonState = HIGH;
unsigned long lastPotUpdate = 0; // Để kiểm tra thời gian của cập nhật từ B10K
const unsigned long potUpdateInterval = 1000; // Tần suất cập nhật từ B10K (ms)
bool updatedFromPhone = false; // Đánh dấu khi giá trị được cập nhật từ điện thoại

bool startButtonPressed = false;
bool modeButtonPressed = false;

void handleGetSettings(AsyncWebServerRequest* request) {
  DynamicJsonDocument jsonDoc(256);
  jsonDoc["auto_mode"] = isAutoMode;
  jsonDoc["manual_mode"] = isManualOn;
  jsonDoc["wine_number"] = mlAmount;
  jsonDoc["start_button_pressed"] = startButtonPressed;
  jsonDoc["mode_button_pressed"] = modeButtonPressed;

  String jsonResponse;
  serializeJson(jsonDoc, jsonResponse);
  request->send(200, "application/json", jsonResponse);
}

void handleTest(AsyncWebServerRequest* request) {
  if (request->hasParam("leg")) {
    String legValue = request->getParam("leg")->value();
    isAutoMode = (legValue == "true");
    preferences.putBool("isAutoMode", isAutoMode);

    lcd.clear();
    if (isAutoMode) {
      lcd.setCursor(0, 0);
      lcd.print("Che do Auto");
      updateAutoModeDisplay();
    } else {
      lcd.setCursor(0, 0);
      lcd.print("Che do Manual");
      updateManualMode();
    }

    request->send(200, "text/plain", legValue);
    Serial.println(isAutoMode);
  } else {
    request->send(400, "text/plain", "Fail");
  }
}

void handleManualButton(AsyncWebServerRequest* request) {
  if (request->hasParam("button")) {
    String buttonValue = request->getParam("button")->value();
    isManualOn = (buttonValue == "true");
    preferences.putBool("isManualOn", isManualOn);

    updateManualMode();
    request->send(200, "text/plain", buttonValue == "true" ? "Manual is running" : "Manual is off");
    Serial.println(buttonValue);
  } else {
    request->send(400, "text/plain", "Fail");
  }
}

void handleNumber(AsyncWebServerRequest* request) {
  if (request->hasParam("number")) {
    mlAmount = request->getParam("number")->value().toFloat();
    preferences.putFloat("mlAmount", mlAmount);

    updateAutoModeDisplay(); // Display updated value on LCD
    updatedFromPhone = true; // Mark that the value was updated from the phone

    request->send(200, "text/plain", "Number of wine is: " + String(mlAmount));
    Serial.println(mlAmount);
  } else {
    request->send(400, "text/plain", "Fail");
  }
}

void updateAutoModeDisplay() {
  lcd.setCursor(0, 1);
  lcd.print("Luong: ");
  lcd.print(mlAmount);
  lcd.print(" ml ");
}

void updateManualMode() {
  lcd.setCursor(0, 1);
  if (isManualOn) {
    lcd.print("Dang bat ");
    digitalWrite(RELAY_PIN, HIGH);
  } else {
    lcd.print("Dang tat ");
    digitalWrite(RELAY_PIN, LOW);
  }
}

void setup() {
  lcd.init();
  lcd.backlight();
  Serial.begin(9600);
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(VAL_SENSOR, INPUT);
  pinMode(Mode_Button, INPUT);
  pinMode(Start_Button, INPUT_PULLUP);
  pinMode(POT_PIN, INPUT);

  preferences.begin("settings", false);
  isAutoMode = preferences.getBool("isAutoMode", true);
  isManualOn = preferences.getBool("isManualOn", false);
  mlAmount = preferences.getFloat("mlAmount", 0);
  lastB10KValue = mlAmount; // Khởi tạo lastB10KValue bằng giá trị lưu trữ ban đầu

  lcd.clear();
  if (isAutoMode) {
    lcd.setCursor(0, 0);
    lcd.print("Che do Auto");
    updateAutoModeDisplay();
  } else {
    lcd.setCursor(0, 0);
    lcd.print("Che do Manual");
    updateManualMode();
  }

  WiFi.softAPConfig(local_IP, gateway, subnet);
  WiFi.softAP(ssid, password);

  server.on("/test", HTTP_GET, handleTest);
  server.on("/manual", HTTP_GET, handleManualButton);
  server.on("/winenumber", HTTP_GET, handleNumber);
  server.on("/getSettings", HTTP_GET, handleGetSettings);

  ws.onEvent(onWebSocketEvent);
  server.addHandler(&ws);

  server.begin();
}

void onWebSocketEvent(AsyncWebSocket* server, AsyncWebSocketClient* client, AwsEventType type, void* arg, uint8_t* data, size_t len) {
  if (type == WS_EVT_CONNECT) {
    Serial.println("WebSocket client connected");
  } else if (type == WS_EVT_DISCONNECT) {
    Serial.println("WebSocket client disconnected");
  }
}

void sendDataToClient() {
  DynamicJsonDocument jsonDoc(256);
  jsonDoc["isAutoMode"] = isAutoMode;
  jsonDoc["mlAmount"] = mlAmount;
  jsonDoc["sensorValue"] = sensorValue;
  jsonDoc["hasPoured"] = hasPoured;
  jsonDoc["isManualOn"] = isManualOn;
  jsonDoc["start_button_pressed"] = startButtonPressed;
  jsonDoc["mode_button_pressed"] = modeButtonPressed;

  String jsonString;
  serializeJson(jsonDoc, jsonString);
  ws.textAll(jsonString);
}

void loop() {
  if (digitalRead(Mode_Button) == LOW) {
    modeButtonPressed = true;
    isAutoMode = !isAutoMode;
    preferences.putBool("isAutoMode", isAutoMode);

    lcd.clear();
    if (isAutoMode) {
      lcd.setCursor(0, 0);
      lcd.print("Che do Auto");
      updateAutoModeDisplay();
    } else {
      lcd.setCursor(0, 0);
      lcd.print("Che do Manual");
      updateManualMode();
    }
    sendDataToClient();
    delay(500); // Debounce delay
  } else {
    modeButtonPressed = false;
  }

  if (digitalRead(Start_Button) == LOW) {
    startButtonPressed = true;
    sendDataToClient();
    delay(500); // Debounce delay
  } else {
    startButtonPressed = false;
  }

  if (isAutoMode) {
    sensorValue = digitalRead(VAL_SENSOR);

    // Update from B10K every potUpdateInterval ms
    if (millis() - lastPotUpdate >= potUpdateInterval) {
      int potValue = analogRead(POT_PIN);
      float newB10KValue = map(potValue, 0, 4095, 0, 50);

      if (newB10KValue != lastB10KValue && !updatedFromPhone) {
        mlAmount = newB10KValue;
        lastB10KValue = newB10KValue;
        preferences.putFloat("mlAmount", mlAmount);
        updateAutoModeDisplay();
        sendDataToClient();
        lastPotUpdate = millis();
      }
      updatedFromPhone = false;
    }

    if (sensorValue == 0 && !hasPoured) {
      delay(1000);
      digitalWrite(RELAY_PIN, HIGH);
      int pumpTime = (mlAmount / flowRate) * 1000;
      delay(pumpTime);
      digitalWrite(RELAY_PIN, LOW);
      hasPoured = true;
    }
    if (sensorValue == 1) {
      hasPoured = false;
    }
    Serial.println(1);
  } else {
    bool currentButtonState = digitalRead(Start_Button);
    if (currentButtonState == LOW && lastButtonState == HIGH) {
      isManualOn = !isManualOn;
      updateManualMode();
      preferences.putBool("isManualOn", isManualOn);
      delay(500);
    }
    lastButtonState = currentButtonState;
    Serial.println(0);
  }

  delay(100);
}

