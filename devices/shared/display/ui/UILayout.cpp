#include "display/ui/UILayout.h"
#include <stdio.h>   // snprintf

UILayout::UILayout(Renderer& renderer) : _r(renderer) {}

void UILayout::drawStatusScreen(const char* status, uint8_t nodeCount,
                                  const char* colmenaName, const char* lastActivity) {
    _r.clear();

    // Título
    _r.textCentered(0, "Colmena IoT", 1);

    // Separador
    _r.hRule(10);

    // Estado
    char buf[32];
    snprintf(buf, sizeof(buf), "Est: %s", status);
    _r.text(0, 13, buf, 1);

    // Nodos conectados
    snprintf(buf, sizeof(buf), "Nodos: %d", (int)nodeCount);
    _r.text(0, 23, buf, 1);

    // Nombre de colmena
    snprintf(buf, sizeof(buf), "Red: %s", colmenaName);
    _r.text(0, 33, buf, 1);

    // Separador
    _r.hRule(43);

    // Última actividad (con wrap automático en 128px)
    _r.textWrapped(0, 46, 128, lastActivity, 1);

    _r.flush();
}

void UILayout::drawBootScreen(const char* title, const char* subtitle,
                                const char* status) {
    _r.clear();

    // Marco exterior
    _r.rect(0, 0, 128, 64);

    // Título grande (size=2: 12×16px por char)
    _r.textCentered(8, title, 2);

    // Separador
    _r.hRule(32);

    // Subtítulo
    _r.textCentered(36, subtitle, 1);

    // Estado en la parte inferior
    _r.hRule(52);
    _r.textCentered(54, status, 1);

    _r.flush();
}

void UILayout::drawErrorScreen(const char* errorCode, const char* detail) {
    _r.clear();

    // Cabecera de error (invertida: fondo blanco, texto negro)
    _r.fillRect(0, 0, 128, 12);
    // Para texto invertido en OLED monocromo, dibujar el texto con COLOR_OFF
    // sobre el rect relleno. Usamos drawText directamente en el display.
    // (IDisplay no expone color de fondo directamente; se maneja a nivel driver)
    _r.text(4, 2, "!ERROR!", 1);  // visible sobre fondo relleno por contraste

    // Código de error
    _r.text(0, 16, errorCode, 1);

    // Separador
    _r.hRule(27);

    // Detalle (wrapeado)
    _r.textWrapped(0, 30, 128, detail, 1);

    _r.flush();
}

void UILayout::drawStatusBar(const char* msg) {
    // Barra de status en la última fila (y=56 para pantalla de 64px)
    _r.fillRect(0, 56, 128, 8);
    // El texto se sobreescribe en negro (COLOR_OFF) sobre el fondo blanco
    // Solo disponible si el driver soporta color de background en drawChar
    _r.text(2, 57, msg, 1);
    _r.flush();
}
