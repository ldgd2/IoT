#ifndef RADIO_CONFIG_H
#define RADIO_CONFIG_H

#ifdef IS_RP2040
  // Pines para Raspberry Pi Pico YD-RP2040
  #define CE_PIN  14
  #define CSN_PIN 15
#elif defined(IS_ESP8266)
  // Pines para NodeMCU / ESP8266
  #define CE_PIN  D4 // GPIO2
  #define CSN_PIN D8 // GPIO15
#else
  // Pines defecto
  #define CE_PIN  7
  #define CSN_PIN 8
#endif

// Evasión WiFi: Usar banda 2.500 GHz (Canal 100)
#define RF_CHANNEL 100 

// Robustez y distancia: Ancho de banda de 1Mbps (compatible con 100% de chips NRF24L01/Si24R1 y 4x más veloz)
#define RF_DATARATE RF24_1MBPS

#endif
