#include <Arduino.h>
#include <SPI.h>
#include <RF24.h>
#include <ArduinoJson.h>
#include "../config/Protocol.h"
#include "../config/RadioConfig.h"

RF24 radio(CE_PIN, CSN_PIN);
const uint64_t rxAddress = 0x7878787878LL;
const uint64_t txAddress = 0xB3B4B5B6F1LL;

unsigned long lastHeartbeat = 0;

#ifdef IS_RP2040
  #include "Adafruit_TinyUSB.h"

  // Report descriptor for generic HID: 64 bytes IN, 64 bytes OUT
  uint8_t const desc_hid_report[] = {
    TUD_HID_REPORT_DESC_GENERIC_INOUT(64)
  };

  Adafruit_USBD_HID usb_hid(desc_hid_report, sizeof(desc_hid_report), HID_ITF_PROTOCOL_NONE, 2, false);

  // Callback cuando se recibe un reporte HID desde Python
  void set_report_callback(uint8_t report_id, hid_report_type_t report_type, uint8_t const* buffer, uint16_t bufsize) {
    if (bufsize == 0) return;
    
    // Asumimos que Python envía el paquete crudo de 32 bytes (o envuelto en el reporte de 64)
    if (bufsize >= sizeof(RFPacket)) {
        RFPacket packet;
        memcpy(&packet, buffer, sizeof(RFPacket));
        
        radio.stopListening();
        bool ok = radio.write(&packet, sizeof(packet));
        radio.startListening();
        
        // Enviar ACK a Python
        uint8_t ack_buf[64] = {0};
        ack_buf[0] = ok ? 1 : 0; // 1 = Exito, 0 = Fallo
        usb_hid.sendReport(0, ack_buf, sizeof(ack_buf));
    }
  }
#endif

void setup() {
#ifdef IS_RP2040
    // Configurar Nombres USB y VIDs/PIDs
    TinyUSBDevice.setManufacturerDescriptor("Colmena IoT");
    TinyUSBDevice.setProductDescriptor("IoT RF Gateway (Traductor)");
    TinyUSBDevice.setID(0x1234, 0x5678); // VID = 0x1234, PID = 0x5678
    
    usb_hid.setReportCallback(NULL, set_report_callback);
    usb_hid.begin();
    
    // Esperar a que la PC monte el USB HID
    while (!TinyUSBDevice.mounted()) delay(1);
#else
    // Inicialización Serial para ESP8266 / Arduino
    Serial.begin(115200);
    while (!Serial) {} 
#endif
    
    if (!radio.begin()) {
#ifndef IS_RP2040
        Serial.println("{\"error\": \"radio_hardware_not_responding\"}");
#endif
        while (1) {}
    }
    
    radio.setChannel(RF_CHANNEL);
    radio.setDataRate(RF_DATARATE);
    radio.setPALevel(RF24_PA_MAX);
    
    radio.openWritingPipe(txAddress);
    radio.openReadingPipe(1, rxAddress);
    radio.startListening();
    
#ifndef IS_RP2040
    Serial.println("{\"status\": \"translator_ready\"}");
#endif
}

void loop() {
    // 1. Leer paquetes RF y enviarlos a la PC
    if (radio.available()) {
        RFPacket packet;
        radio.read(&packet, sizeof(packet));
        
#ifdef IS_RP2040
        // RP2040: Enviar el struct binario directamente por USB HID (Maxima velocidad)
        if (usb_hid.ready()) {
            uint8_t report_buf[64] = {0};
            memcpy(report_buf, &packet, sizeof(packet));
            usb_hid.sendReport(0, report_buf, sizeof(report_buf));
        }
#else
        // ESP8266: Convertir a JSON y enviar por Serial (COM)
        StaticJsonDocument<256> doc;
        doc["origin"] = packet.originId;
        doc["dest"] = packet.destId;
        doc["type"] = packet.deviceType;
        doc["cmd"] = packet.command;
        
        JsonArray dataArray = doc.createNestedArray("data");
        for(int i=0; i<4; i++) dataArray.add(packet.data[i]);
        
        serializeJson(doc, Serial);
        Serial.println();
#endif
    }
    
    // 2. Leer comandos desde el PC hacia el hardware
#ifndef IS_RP2040
    if (Serial.available()) {
        String input = Serial.readStringUntil('\n');
        StaticJsonDocument<256> doc;
        DeserializationError err = deserializeJson(doc, input);
        
        if (!err) {
            RFPacket packet;
            packet.originId = 0x01; // ID del Gateway
            packet.destId = doc["dest"] | 0xFF;
            packet.deviceType = DEV_TYPE_GATEWAY;
            packet.command = doc["cmd"] | CMD_ON;
            
            radio.stopListening();
            bool ok = radio.write(&packet, sizeof(packet));
            radio.startListening();
            
            StaticJsonDocument<128> ack;
            ack["ack"] = ok;
            serializeJson(ack, Serial);
            Serial.println();
        }
    }
#endif
    
    // 3. Heartbeat autonomo de Gateway
    if (millis() - lastHeartbeat > 30000) {
        lastHeartbeat = millis();
        RFPacket hb;
        hb.originId = 0x01;
        hb.destId = 0xFF;
        hb.deviceType = DEV_TYPE_GATEWAY;
        hb.command = CMD_HEARTBEAT;
        
        radio.stopListening();
        radio.write(&hb, sizeof(hb));
        radio.startListening();
    }
}
