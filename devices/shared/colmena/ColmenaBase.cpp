#include "colmena/ColmenaBase.h"

ColmenaBase::ColmenaBase(IConnection& conn, IParamStore& store)
    : _conn(conn), _store(store)
{
    _loadDefaults();
}

void ColmenaBase::_loadDefaults() {
    _p.nodeId            = 1;
    _p.rfChannel         = DEFAULT_RF_CHANNEL;
    _p.rfDataRate        = DEFAULT_RF_DATARATE;
    _p.heartbeatInterval = DEFAULT_HEARTBEAT_SECS;
    _p.deviceType        = DEV_TYPE_LIGHT;
    _p.features          = FEATURE_RELAY;
    _p.fwVersion         = 0x10;
    strncpy(_p.colmenaName, DEFAULT_COLMENA_NAME, sizeof(_p.colmenaName) - 1);
    _p.colmenaName[sizeof(_p.colmenaName) - 1] = '\0';
}

void ColmenaBase::load() {
    _p.nodeId            = _store.getUInt8 ("node_id",  _p.nodeId);
    _p.rfChannel         = _store.getUInt8 ("rf_ch",    _p.rfChannel);
    _p.rfDataRate        = _store.getUInt8 ("rf_dr",    _p.rfDataRate);
    _p.heartbeatInterval = _store.getUInt8 ("hb_secs",  _p.heartbeatInterval);
    _p.deviceType        = _store.getUInt8 ("dev_type", _p.deviceType);
    _p.features          = _store.getUInt8 ("features", _p.features);
    _store.getString("col_name", _p.colmenaName, sizeof(_p.colmenaName), _p.colmenaName);
}

void ColmenaBase::save() {
    _store.putUInt8 ("node_id",  _p.nodeId);
    _store.putUInt8 ("rf_ch",    _p.rfChannel);
    _store.putUInt8 ("rf_dr",    _p.rfDataRate);
    _store.putUInt8 ("hb_secs",  _p.heartbeatInterval);
    _store.putUInt8 ("dev_type", _p.deviceType);
    _store.putUInt8 ("features", _p.features);
    _store.putString("col_name", _p.colmenaName);
    _store.commit();
}

void ColmenaBase::reset() {
    _loadDefaults();
    _store.clear();
    save();
}
