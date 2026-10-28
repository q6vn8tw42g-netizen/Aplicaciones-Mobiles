-- Los espacios ya almacenan GPS en lat/lng. Estas columnas generadas ofrecen
-- nombres explícitos sin duplicar ni desincronizar esos valores existentes.
ALTER TABLE public.espacios
    ADD COLUMN IF NOT EXISTS coordenada_lat double precision
        GENERATED ALWAYS AS (lat) STORED,
    ADD COLUMN IF NOT EXISTS coordenada_lng double precision
        GENERATED ALWAYS AS (lng) STORED,
    ADD COLUMN IF NOT EXISTS estado_visibilidad boolean NOT NULL DEFAULT false;
