#include "UILayout.h"
#include "../../error/ColmenaError.h"
#include <stdio.h>   // snprintf
#include <Arduino.h> // delay, millis

UILayout::UILayout(Renderer& renderer) : _r(renderer) {}

void UILayout::drawStatusScreen(const char* status, uint8_t nodeCount,
                                  const char* colmenaName, const char* lastActivity) {
    _r.clear();

    // 1. Título
    _r.textCentered(0, "Colmena IoT", 1);
    _r.hRule(9);

    // 2. Línea de estado
    char buf[32];
    snprintf(buf, sizeof(buf), "Est: %s", status);
    _r.text(0, 12, buf, 1);

    // 3. Nodos conectados
    snprintf(buf, sizeof(buf), "Nodos: %d", nodeCount);
    _r.text(0, 22, buf, 1);

    // 4. Nombre de la red
    snprintf(buf, sizeof(buf), "Red: %s", colmenaName ? colmenaName : "colmena");
    _r.text(0, 32, buf, 1);

    // 5. Separador y última actividad
    _r.hRule(42);
    _r.textWrapped(0, 45, 128, lastActivity ? lastActivity : "", 1);

    _r.flush();
}

void UILayout::drawBootScreen(const char* title, const char* subtitle, const char* status) {
    _r.clear();

    _r.textCentered(12, title ? title : "Colmena", 1);
    if (subtitle) {
        _r.textCentered(24, subtitle, 1);
    }
    _r.hRule(38);
    _r.textCentered(45, status ? status : "Iniciando...", 1);

    _r.flush();
}

void UILayout::drawErrorScreen(const char* errorCode, const char* detail) {
    _r.clear();

    // Cabecera limpia y centrada en caja de contorno (sin solapamiento)
    _r.rect(0, 0, 128, 12);
    char header[32];
    snprintf(header, sizeof(header), "ERROR: %s", errorCode ? errorCode : "GEN");
    _r.textCentered(2, header, 1);

    _r.hRule(14);
    _r.textWrapped(0, 18, 128, detail ? detail : "", 1);

    _r.flush();
}

void UILayout::drawStatusBar(const char* msg) {
    _r.fillRect(0, 55, 128, 9);
    _r.text(2, 56, msg ? msg : "", 1);
    _r.flush();
}

// ── Animaciones a tiempo real ─────────────────────────────────────────────

void UILayout::drawIntroAnimation() {
    for (int frame = 0; frame <= 20; frame++) {
        _r.clear();
        int w = (128 * frame) / 20;
        int h = (64 * frame) / 20;
        int x = (128 - w) / 2;
        int y = (64 - h) / 2;
        _r.rect(x, y, w, h);

        if (frame > 10) {
            _r.textCentered(20, "COLMENA IoT", 1);
            _r.textCentered(32, "Sistema Inteligente", 1);
            _r.progressBar(14, 48, 100, 8, (frame - 10) * 10);
        }
        _r.flush();
        delay(40);
    }
}

void UILayout::drawPairingAnimation(const char* colmenaName, uint8_t step) {
    _r.clear();
    _r.textCentered(6, "Buscando Nodos...", 1);
    _r.hRule(18);

    int radius = 4 + (step % 4) * 5;
    _r.circle(64, 38, radius);
    if (radius > 8)  _r.circle(64, 38, radius - 6);
    if (radius > 14) _r.circle(64, 38, radius - 12);

    _r.textCentered(35, "(((.)))", 1);
    _r.textCentered(52, colmenaName ? colmenaName : "colmena", 1);
    _r.flush();
}

void UILayout::drawDeviceDetectedAnimation(const char* nodeName, uint8_t nodeId, uint8_t devType) {
    for (int i = 0; i < 3; i++) {
        _r.clear();
        _r.fillRect(0, 0, 128, 16);
        _r.textCentered(4, "! NUEVO DISPOSITIVO !", 1);

        char buf[32];
        snprintf(buf, sizeof(buf), "ID: %d | Tipo: 0x%02X", nodeId, devType);
        _r.textCentered(24, buf, 1);
        _r.textCentered(38, nodeName ? nodeName : "Nodo Sensor", 1);
        _r.textCentered(52, "* Sincronizado *", 1);
        _r.flush();
        delay(180);

        _r.clear();
        _r.rect(0, 0, 128, 16);
        _r.textCentered(4, "! NUEVO DISPOSITIVO !", 1);
        _r.textCentered(24, buf, 1);
        _r.textCentered(38, nodeName ? nodeName : "Nodo Sensor", 1);
        _r.flush();
        delay(140);
    }
}

void UILayout::drawLiveStatusScreen(const char* status, uint8_t nodeCount,
                                      const char* colmenaName, const char* lastActivity,
                                      uint8_t animFrame) {
    _r.clear();

    // Cabecera con indicador de radar/antena animado
    _r.text(0, 0, "Colmena IoT", 1);
    const char* radarFrames[] = { "|", "/", "-", "\\" };
    _r.text(118, 0, radarFrames[animFrame % 4], 1);
    _r.hRule(9);

    char buf[32];
    snprintf(buf, sizeof(buf), "Est: %s", status);
    _r.text(0, 12, buf, 1);

    snprintf(buf, sizeof(buf), "Nodos: %d en red", nodeCount);
    _r.text(0, 22, buf, 1);

    snprintf(buf, sizeof(buf), "Malla: %s", colmenaName ? colmenaName : "colmena");
    _r.text(0, 32, buf, 1);

    _r.hRule(42);
    _r.textWrapped(0, 45, 128, lastActivity ? lastActivity : "Escaneando...", 1);

    _r.flush();
}

// ── Sistema de Errores Formateados y Easter Eggs ──────────────────────────

void UILayout::drawSystemError(uint16_t errorCode) {
    const ErrorInfo* info = ColmenaError::get(errorCode);
    if (info) {
        drawSystemErrorCustom(errorCode, info->detail);
    } else {
        drawSystemErrorCustom(errorCode, "Fallo no especificado en el sistema.");
    }
}

void UILayout::drawSystemErrorCustom(uint16_t errorCode, const char* customDetail) {
    const ErrorInfo* info = ColmenaError::get(errorCode);
    const char* titleStr = info ? info->title : "ERROR DESCONOCIDO";

    _r.clear();

    // 1. Cabecera limpia sin solapamientos
    _r.rect(0, 0, 128, 12);
    char header[32];
    snprintf(header, sizeof(header), "ERROR: ERR-%03d", errorCode);
    _r.textCentered(2, header, 1);

    // 2. Título principal
    _r.textCentered(14, titleStr, 1);
    _r.hRule(24);

    // 3. Detalle con amplio espacio sin pisarse
    _r.text(0, 26, "Detalle:", 1);
    _r.textWrapped(0, 36, 128, customDetail ? customDetail : "", 1);

    _r.flush();
}

void UILayout::drawAnimatedError(const ErrorInfo* info, uint8_t frame) {
    if (!info) return;

    _r.clear();

    // 1. Cabecera sólida y estable (SIN PARPADEOS)
    _r.rect(0, 0, 128, 12);
    char header[32];
    if (info->severity == SEV_CRITICAL) {
        snprintf(header, sizeof(header), "CRITICO: ERR-%03d", info->code);
    } else if (info->severity == SEV_WARN) {
        snprintf(header, sizeof(header), "ALERTA:  ERR-%03d", info->code);
    } else if (info->severity == SEV_EASTER_EGG) {
        snprintf(header, sizeof(header), "EASTER:  ERR-%03d", info->code);
    } else {
        snprintf(header, sizeof(header), "INFO:    ERR-%03d", info->code);
    }
    _r.textCentered(2, header, 1);

    // 2. Título principal
    _r.textCentered(14, info->title, 1);
    _r.hRule(24);

    // 3. Paginación limpia: Alterna cada 3.5s (45 frames) entre el Detalle y la Solución (Fix)
    // Esto garantiza que el texto NUNCA se sobreponga ni se vuelva ilegible
    bool showFix = (info->suggestedFix != nullptr) && ((frame / 45) % 2 == 1) && (info->severity != SEV_EASTER_EGG);

    if (showFix) {
        _r.text(0, 26, "Solucion (Fix):", 1);
        _r.textWrapped(0, 36, 128, info->suggestedFix, 1);
    } else {
        if (info->severity == SEV_EASTER_EGG) {
            _r.textWrapped(0, 26, 128, info->detail, 1);
        } else {
            _r.text(0, 26, "Detalle del Fallo:", 1);
            _r.textWrapped(0, 36, 128, info->detail, 1);
        }
    }

    // 4. Pie animado exclusivo para Easter Eggs o indicador visual discreto de sistema activo
    if (info->severity == SEV_EASTER_EGG) {
        _r.hRule(48);
        if (info->code == 666) { // Abejas
            int16_t x = (frame * 5) % 128;
            _r.text(x, 52, "~(8)> bzzz", 1);
        } else if (info->code == 404) { // Café
            _r.textCentered(52, (frame % 2 == 0) ? "[c]~ Buscando Cafe..." : "[c]  Buscando Cafe...", 1);
        } else if (info->code == 67) { // 67
            _r.textCentered(52, (frame % 2 == 0) ? ">> 6 o 7 corruptos <<" : "<< 6 o 7 corruptos >>", 1);
        } else if (info->code == 808) { // Homero
            _r.textCentered(52, (frame % 2 == 0) ? "♫ Marge soy BR ♫" : "♪ Marge soy BR ♪", 1);
        } else if (info->code == 418) { // Tetera
            _r.textCentered(52, (frame % 2 == 0) ? "(_)> Soy una tetera" : "(_)/ Soy una tetera", 1);
        } else if (info->code == 777) { // Jackpot / Paquetes
            _r.textCentered(52, (frame % 2 == 0) ? "[$$$] Tio nooo [$$$]" : "[***] Tio nooo [***]", 1);
        } else {
            _r.textCentered(52, (frame % 2 == 0) ? "* EASTER EGG ACTIVO *" : "- EASTER EGG ACTIVO -", 1);
        }
    } else {
        // Indicador discreto y elegante en esquina inferior derecha para mostrar que el sistema está vivo
        int16_t dotX = 116 + ((frame / 3) % 3) * 3;
        _r.fillRect(dotX, 58, 2, 2);
    }

    _r.flush();
}
