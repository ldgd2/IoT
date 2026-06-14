#include <Arduino.h>
#include <SPI.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <RF24.h>
#include <RF24Network.h>
#include <RF24Mesh.h>
#include <ArduinoJson.h>
#include "../config/Protocol.h"
#include "../config/RadioConfig.h"

// Inicialización de la pantalla OLED
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Inicialización de Radio y Mesh
RF24 radio(CE_PIN, CSN_PIN);
RF24Network network(radio);
RF24Mesh mesh(radio, network);

// El Gateway siempre es el Nodo 0 (Maestro)
#define MESH_MASTER_NODE_ID 0

unsigned long lastHeartbeat = 0;
String currentStatus = "Iniciando...";
String lastActivity = "Ninguna";

// Función auxiliar para refrescar la pantalla
void updateDisplay() {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 0);
    display.println("Colmena IoT Gateway");
    display.println("-------------------");
    display.print("Est: ");
    display.println(currentStatus);
    display.println("Nodos Conectados:");
    display.println(mesh.addrListTop); // Número de nodos enrutados
    display.println("-------------------");
    display.println("Actividad:");
    display.println(lastActivity);
    display.display();
}

#ifdef IS_RP2040
  #include "Adafruit_TinyUSB.h"

  uint8_t const desc_hid_report[] = {
    TUD_HID_REPORT_DESC_GENERIC_INOUT(64)
  };

  Adafruit_USBD_HID usb_hid(desc_hid_report, sizeof(desc_hid_report), HID_ITF_PROTOCOL_NONE, 2, false);

  void set_report_callback(uint8_t report_id, hid_report_type_t report_type, uint8_t const* buffer, uint16_t bufsize) {
    if (bufsize >= sizeof(RFPacket)) {
        RFPacket packet;
        memcpy(&packet, buffer, sizeof(RFPacket));
        
        // Enviar por la red Mesh (usamos el destId como NodeID de RF24Mesh)
        // El caracter 'C' (Command) sirve como tipo de cabecera arbitraria
        bool ok = mesh.write(&packet, 'C', sizeof(packet), packet.destId);
        
        uint8_t ack_buf[64] = {0};
        ack_buf[0] = ok ? 1 : 0; 
        usb_hid.sendReport(0, ack_buf, sizeof(ack_buf));
        
        lastActivity = "Tx -> Nodo " + String(packet.destId) + (ok ? " [OK]" : " [FAIL]");
        updateDisplay();
    }
  }
#endif

void setup() {
    // Inicializar Pantalla I2C (SDA, SCL por defecto)
    Wire.begin();
    if (display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
        display.clearDisplay();
        display.display();
    }

#ifdef IS_RP2040
    TinyUSBDevice.setManufacturerDescriptor("Gerlex");
    TinyUSBDevice.setProductDescriptor("IoT RF Gateway");
    TinyUSBDevice.setID(0x1234, 0x5678); 
    
    usb_hid.setReportCallback(NULL, set_report_callback);
    usb_hid.begin();
    
    while (!TinyUSBDevice.mounted()) delay(1);
    currentStatus = "USB HID Listo";
#else
    Serial.begin(115200);
    while (!Serial) {} 
    currentStatus = "Serial COM Listo";
#endif
    
    updateDisplay();
    
    // Configurar RF24Mesh
    mesh.setNodeID(MESH_MASTER_NODE_ID);
    currentStatus = "Iniciando Mesh...";
    updateDisplay();
    
    if (!mesh.begin()) {
        currentStatus = "ERROR RADIO (SPI)";
        updateDisplay();
#ifndef IS_RP2040
        Serial.println("{\"error\": \"radio_hardware_not_responding\"}");
#endif
        while (1) {}
    }
    
    radio.setPALevel(RF24_PA_MAX);
    radio.setDataRate(RF_DATARATE);
    
    currentStatus = "MESH MASTER ACTIVO";
    updateDisplay();
    
#ifndef IS_RP2040
    Serial.println("{\"status\": \"translator_ready\"}");
#endif
}

void loop() {
    // 1. Mantener la red Mesh viva (Asignar IPs/Direcciones DHCP a los nodos)
    mesh.update();
    mesh.DHCP();
    
    // 2. Leer paquetes entrantes de cualquier nodo de la red
    if (network.available()) {
        RF24NetworkHeader header;
        RFPacket packet;
        network.read(header, &packet, sizeof(packet));
        
        int fromNode = mesh.getNodeID(header.from_node);
        lastActivity = "Rx <- Nodo " + String(fromNode);
        updateDisplay();
        
#ifdef IS_RP2040
        if (usb_hid.ready()) {
            uint8_t report_buf[64] = {0};
            memcpy(report_buf, &packet, sizeof(packet));
            usb_hid.sendReport(0, report_buf, sizeof(report_buf));
        }
#else
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
    
    // 3. Leer comandos desde el PC hacia el hardware (ESP8266/Serial)
#ifndef IS_RP2040
    if (Serial.available()) {
        String input = Serial.readStringUntil('\n');
        StaticJsonDocument<256> doc;
        DeserializationError err = deserializeJson(doc, input);
        
        if (!err) {
            RFPacket packet;
            packet.originId = MESH_MASTER_NODE_ID;
            packet.destId = doc["dest"] | 0xFF;
            packet.deviceType = DEV_TYPE_GATEWAY;
            packet.command = doc["cmd"] | CMD_ON;
            
            bool ok = mesh.write(&packet, 'C', sizeof(packet), packet.destId);
            
            StaticJsonDocument<128> ack;
            ack["ack"] = ok;
            serializeJson(ack, Serial);
            Serial.println();
            
            lastActivity = "Tx -> Nodo " + String(packet.destId) + (ok ? " [OK]" : " [FAIL]");
            updateDisplay();
        }
    }
#endif
    
    // 4. Heartbeat autonomo y refresco de pantalla
    if (millis() - lastHeartbeat > 30000) {
        lastHeartbeat = millis();
        // El heartbeat no se envia por radio en el master, el master solo recibe
        updateDisplay();
    }
}
