-- =====================================================================
-- MotoMap - Esquema remoto PostgreSQL 14+ + PostGIS 3+
-- Uso:  createdb motomap && psql -d motomap -f schema_postgis.sql
-- =====================================================================
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TYPE tipo_motor AS ENUM ('COMBUSTION', 'ELECTRICA', 'AMBOS');

-- Trigger genérico para updated_at
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- 1) Estaciones de gasolina (modo COMBUSTIÓN)
-- ---------------------------------------------------------------------
CREATE TABLE estaciones_gasolina (
    id                 BIGSERIAL PRIMARY KEY,
    nombre             VARCHAR(150) NOT NULL,
    bandera            VARCHAR(80),                        -- Terpel, Primax, Texaco...
    direccion          VARCHAR(255),
    telefono           VARCHAR(30),
    ubicacion          GEOMETRY(Point, 4326) NOT NULL,     -- (lng, lat) WGS84
    precio_corriente   NUMERIC(10,2) CHECK (precio_corriente >= 0),  -- por galón
    precio_extra       NUMERIC(10,2) CHECK (precio_extra >= 0),
    horario            VARCHAR(120),
    activo             BOOLEAN NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_estaciones_ubicacion ON estaciones_gasolina USING GIST (ubicacion);
CREATE INDEX idx_estaciones_activo    ON estaciones_gasolina (activo) WHERE activo;
CREATE TRIGGER trg_estaciones_updated BEFORE UPDATE ON estaciones_gasolina
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- 2) Puntos de carga (modo ELÉCTRICA)
-- ---------------------------------------------------------------------
CREATE TABLE puntos_carga (
    id                  BIGSERIAL PRIMARY KEY,
    nombre              VARCHAR(150) NOT NULL,
    operador            VARCHAR(100),
    direccion           VARCHAR(255),
    ubicacion           GEOMETRY(Point, 4326) NOT NULL,
    marcas_compatibles  TEXT[] NOT NULL DEFAULT '{}',      -- {} = compatible con todas
    tipo_conector       VARCHAR(40),                       -- Tipo 2, CCS, GB/T, Schuko...
    potencia_kw         NUMERIC(6,2) CHECK (potencia_kw > 0),
    cantidad_puertos    SMALLINT NOT NULL DEFAULT 1 CHECK (cantidad_puertos > 0),
    precio_kwh          NUMERIC(10,2) CHECK (precio_kwh >= 0),
    horario             VARCHAR(120),
    activo              BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_puntos_ubicacion ON puntos_carga USING GIST (ubicacion);
CREATE INDEX idx_puntos_marcas    ON puntos_carga USING GIN (marcas_compatibles);
CREATE INDEX idx_puntos_activo    ON puntos_carga (activo) WHERE activo;
CREATE TRIGGER trg_puntos_updated BEFORE UPDATE ON puntos_carga
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- 3) Talleres mecánicos (ambos modos)
-- ---------------------------------------------------------------------
CREATE TABLE talleres_mecanicos (
    id                  BIGSERIAL PRIMARY KEY,
    nombre              VARCHAR(150) NOT NULL,
    direccion           VARCHAR(255),
    telefono            VARCHAR(30),
    ubicacion           GEOMETRY(Point, 4326) NOT NULL,
    tipo_motor          tipo_motor NOT NULL DEFAULT 'COMBUSTION',
    marcas_compatibles  TEXT[] NOT NULL DEFAULT '{}',      -- marcas que atienden
    presupuesto_max     NUMERIC(12,2) CHECK (presupuesto_max >= 0), -- costo promedio / techo de servicio
    especialidades      TEXT[] NOT NULL DEFAULT '{}',      -- {'frenos','bateria','motor_electrico'}
    horario             VARCHAR(120),
    activo              BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_talleres_ubicacion ON talleres_mecanicos USING GIST (ubicacion);
CREATE INDEX idx_talleres_marcas    ON talleres_mecanicos USING GIN (marcas_compatibles);
CREATE INDEX idx_talleres_tipo      ON talleres_mecanicos (tipo_motor);
CREATE INDEX idx_talleres_activo    ON talleres_mecanicos (activo) WHERE activo;
CREATE TRIGGER trg_talleres_updated BEFORE UPDATE ON talleres_mecanicos
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- Datos de ejemplo (Bucaramanga)  -- ST_MakePoint(lng, lat)
-- ---------------------------------------------------------------------
INSERT INTO estaciones_gasolina (nombre, bandera, direccion, ubicacion, precio_corriente, precio_extra) VALUES
('EDS Cabecera', 'Terpel', 'Cra 33 #48', ST_SetSRID(ST_MakePoint(-73.1105, 7.1180), 4326), 15300, 18400),
('EDS Centro',   'Primax', 'Cll 35 #15', ST_SetSRID(ST_MakePoint(-73.1229, 7.1190), 4326), 15150, 18200);

INSERT INTO puntos_carga (nombre, operador, direccion, ubicacion, marcas_compatibles, tipo_conector, potencia_kw, precio_kwh) VALUES
('Cargador Cacique', 'Enel X', 'C.C. Cacique', ST_SetSRID(ST_MakePoint(-73.1085, 7.0960), 4326), '{Zero,Niu,Super Soco}', 'Tipo 2', 7.4, 1100);

INSERT INTO talleres_mecanicos (nombre, direccion, ubicacion, tipo_motor, marcas_compatibles, presupuesto_max) VALUES
('Moto Taller Pro',   'Cll 45 #28', ST_SetSRID(ST_MakePoint(-73.1190, 7.1170), 4326), 'COMBUSTION', '{Yamaha,Honda,Suzuki,AKT}', 180000),
('E-Moto Service',    'Cra 27 #52', ST_SetSRID(ST_MakePoint(-73.1150, 7.1210), 4326), 'ELECTRICA',  '{Zero,Niu,Super Soco}',     350000);

-- ---------------------------------------------------------------------
-- Consulta de referencia para el endpoint GET /api/v1/puntos-carga
-- (:lng, :lat, :radio_m, :marca)  -> mismo patrón para las otras tablas
-- ---------------------------------------------------------------------
-- SELECT id, nombre, direccion,
--        ST_Y(ubicacion) AS latitud, ST_X(ubicacion) AS longitud,
--        precio_kwh AS precio, 'COP/kWh' AS unidad_precio,
--        marcas_compatibles, activo,
--        ST_Distance(ubicacion::geography,
--                    ST_SetSRID(ST_MakePoint(:lng,:lat),4326)::geography) AS distancia_m
--   FROM puntos_carga
--  WHERE activo
--    AND ST_DWithin(ubicacion::geography,
--                   ST_SetSRID(ST_MakePoint(:lng,:lat),4326)::geography, :radio_m)
--    AND (:marca IS NULL OR marcas_compatibles = '{}' OR :marca = ANY (marcas_compatibles))
--  ORDER BY distancia_m
--  LIMIT 100;

-- ---------------------------------------------------------------------
-- Más datos de ejemplo (Bucaramanga / Floridablanca / Girón)
-- ---------------------------------------------------------------------
INSERT INTO estaciones_gasolina (nombre, bandera, direccion, ubicacion, precio_corriente, precio_extra) VALUES
('EDS La Rosita',     'Texaco',  'Av. Quebradaseca',     ST_SetSRID(ST_MakePoint(-73.1180, 7.1105), 4326), 15250, 18300),
('EDS Provenza',      'Terpel',  'Cra 27 #105',          ST_SetSRID(ST_MakePoint(-73.1020, 7.1050), 4326), 15400, 18500),
('EDS Floridablanca', 'Primax',  'Autopista Floridablanca', ST_SetSRID(ST_MakePoint(-73.0890, 7.0640), 4326), 15100, 18150),
('EDS Girón',         'Biomax',  'Cll 30 Girón',         ST_SetSRID(ST_MakePoint(-73.1690, 7.0690), 4326), 15000, 18000),
('EDS Real de Minas', 'Terpel',  'Cra 15 #12',           ST_SetSRID(ST_MakePoint(-73.1280, 7.1250), 4326), 15350, 18450);

INSERT INTO puntos_carga (nombre, operador, direccion, ubicacion, marcas_compatibles, tipo_conector, potencia_kw, precio_kwh) VALUES
('Cargador Parque del Agua', 'Terpel Voltex', 'Cra 27 #33',    ST_SetSRID(ST_MakePoint(-73.1180, 7.1160), 4326), '{}',                         'Tipo 2',  7.4, 1050),
('Cargador Cabecera',        'Enel X',        'Cll 51 #35',    ST_SetSRID(ST_MakePoint(-73.1090, 7.1215), 4326), '{Zero,Niu,Yadea}',           'Schuko',  2.0,  950),
('Cargador Floridablanca',   'Celsia',        'Cra 9 #4',      ST_SetSRID(ST_MakePoint(-73.0900, 7.0620), 4326), '{Zero,Horwin,Super Soco}',   'Tipo 2', 11.0, 1200);

INSERT INTO talleres_mecanicos (nombre, direccion, ubicacion, tipo_motor, marcas_compatibles, presupuesto_max) VALUES
('Taller Yamaha Autorizado', 'Cll 36 #27',     ST_SetSRID(ST_MakePoint(-73.1210, 7.1200), 4326), 'COMBUSTION', '{Yamaha}',                    250000),
('Motos del Oriente',        'Cra 21 #18',     ST_SetSRID(ST_MakePoint(-73.1260, 7.1160), 4326), 'COMBUSTION', '{Honda,AKT,Bajaj,Suzuki}',    120000),
('Taller Hero y Bajaj',      'Av. 33 #55',     ST_SetSRID(ST_MakePoint(-73.1060, 7.1140), 4326), 'COMBUSTION', '{Hero,Bajaj}',                150000),
('Volt Garage',              'Cll 48 #30',     ST_SetSRID(ST_MakePoint(-73.1120, 7.1190), 4326), 'ELECTRICA',  '{Zero,Niu,Yadea,Horwin}',     280000),
('Electro Moto Service',     'Cra 33 #45',     ST_SetSRID(ST_MakePoint(-73.1075, 7.1200), 4326), 'AMBOS',      '{Honda,Zero,Super Soco}',     200000);
