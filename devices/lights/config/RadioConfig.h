#ifndef RADIO_CONFIG_H
#define RADIO_CONFIG_H

/**
 * @file RadioConfig.h
 * @brief Parámetros de configuración del radio RF — Solo RF, sin pines.
 *
 * Los pines (CE, CSN) están en PinConfig.h.
 * Este archivo define únicamente los parámetros del protocolo RF.
 */

#include <RF24.h>

// Canal RF (0–125). Canal 100 ≈ 2.500 GHz → evita interferencia con WiFi 2.4GHz.
// Todos los nodos de la colmena deben usar el mismo canal.
#define RF_CHANNEL   100

// Velocidad de datos. 1Mbps = estándar hardware universal (compatible con 100% de chips NRF24L01/Si24R1 y 4x más veloz).
// Opciones: RF24_250KBPS, RF24_1MBPS, RF24_2MBPS
#define RF_DATARATE  RF24_1MBPS

#endif // RADIO_CONFIG_H
