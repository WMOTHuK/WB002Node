-- ============================================================================
-- Migration: 001_initial_schema.sql
-- Idempotent migration script - safe to run multiple times
-- ============================================================================

-- ============================================================================
-- Core functions (idempotent with OR REPLACE)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_overheads_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_campaign_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    NEW.last_updated = NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_campaign_update()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    NEW.last_updated = NOW();
    
    IF NEW.active IS DISTINCT FROM OLD.active OR
       NEW.pause_time IS DISTINCT FROM OLD.pause_time OR
       NEW.restart_time IS DISTINCT FROM OLD.restart_time THEN
        
        PERFORM pg_notify('campaign_updated', 
            json_build_object(
                'advertid', NEW.advertid,
                'crmname', NEW.crmname,
                'pause_time', NEW.pause_time,
                'restart_time', NEW.restart_time,
                'active', NEW.active
            )::text
        );
    END IF;
    
    RETURN NEW;
END;
$$;

-- ============================================================================
-- Tables (using IF NOT EXISTS)
-- ============================================================================

-- API key types
CREATE TABLE IF NOT EXISTS public.api_key_types (
    key_type SMALLINT PRIMARY KEY,
    key_text VARCHAR(20)[] NOT NULL
);

-- CRM status reference
CREATE TABLE IF NOT EXISTS public.crm_status (
    crmstatus INTEGER PRIMARY KEY,
    description VARCHAR(40) NOT NULL
);

-- CRM type reference
CREATE TABLE IF NOT EXISTS public.crm_type (
    crmtype INTEGER PRIMARY KEY,
    description VARCHAR(60) NOT NULL
);

-- Localization type reference
CREATE TABLE IF NOT EXISTS public.ltypes (
    loctype INTEGER PRIMARY KEY,
    value_ru TEXT NOT NULL,
    value_en TEXT NOT NULL
);

-- Platform reference
CREATE TABLE IF NOT EXISTS public.gen_platforms (
    id SERIAL PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(50) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Users table
CREATE TABLE IF NOT EXISTS public.users (
    id SERIAL PRIMARY KEY,
    login VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_verified BOOLEAN DEFAULT FALSE,
    verification_token VARCHAR(255)
);

-- User API keys
CREATE TABLE IF NOT EXISTS public.user_api_keys (
    user_id INTEGER NOT NULL,
    key_type SMALLINT NOT NULL,
    api_key TEXT NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, key_type)
);

-- Goods type
CREATE TABLE IF NOT EXISTS public.goods_type (
    id SERIAL PRIMARY KEY,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Goods type localization
CREATE TABLE IF NOT EXISTS public.goods_type_loc (
    id SERIAL PRIMARY KEY,
    goods_type_id INTEGER NOT NULL,
    locale VARCHAR(2) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    CONSTRAINT goods_type_loc_locale_check CHECK (locale IN ('ru', 'en')),
    UNIQUE(goods_type_id, locale)
);

-- Goods group
CREATE TABLE IF NOT EXISTS public.goods_grp (
    id SERIAL PRIMARY KEY,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    goods_type_id INTEGER
);

-- Goods group localization
CREATE TABLE IF NOT EXISTS public.goods_grp_loc (
    id SERIAL PRIMARY KEY,
    goods_grp_id INTEGER NOT NULL,
    locale VARCHAR(2) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    CONSTRAINT goods_grp_loc_locale_check CHECK (locale IN ('ru', 'en')),
    UNIQUE(goods_grp_id, locale)
);

-- Main goods table
CREATE TABLE IF NOT EXISTS public.goods (
    vendorcode VARCHAR(10) PRIMARY KEY,
    nmid INTEGER,
    ozid VARCHAR(12),
    imtid INTEGER,
    subjectid INTEGER,
    subjectname TEXT,
    brand VARCHAR(20),
    title VARCHAR(100),
    deleted BOOLEAN,
    wbvol INTEGER,
    ozvol INTEGER,
    card_photo TEXT,
    goods_grp_id INTEGER
);

-- Product photos
CREATE TABLE IF NOT EXISTS public.photos (
    vendorcode VARCHAR(10) PRIMARY KEY,
    small TEXT,
    big TEXT
);

-- Cost price history
CREATE TABLE IF NOT EXISTS public.cost_price (
    id_cost SERIAL PRIMARY KEY,
    vendorcode VARCHAR(10) NOT NULL,
    cost_value NUMERIC(12,2) NOT NULL,
    beg_date DATE NOT NULL,
    end_date DATE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT cost_price_dates_check CHECK (end_date IS NULL OR beg_date <= end_date),
    UNIQUE(vendorcode, beg_date)
);

-- Overhead group
CREATE TABLE IF NOT EXISTS public.fi_ohgrp (
    id SERIAL PRIMARY KEY,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Overhead group localization
CREATE TABLE IF NOT EXISTS public.fi_ohgrp_loc (
    id SERIAL PRIMARY KEY,
    ohgrp_id INTEGER NOT NULL,
    locale VARCHAR(2) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    CONSTRAINT fi_ohgrp_loc_locale_check CHECK (locale IN ('ru', 'en')),
    UNIQUE(ohgrp_id, locale)
);

-- Overhead category
CREATE TABLE IF NOT EXISTS public.fi_ohcat (
    id SERIAL PRIMARY KEY,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    oh_grp_id INTEGER
);

-- Overhead category localization
CREATE TABLE IF NOT EXISTS public.fi_ohcat_loc (
    id SERIAL PRIMARY KEY,
    ohcat_id INTEGER NOT NULL,
    locale VARCHAR(2) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    CONSTRAINT fi_ohcat_loc_locale_check CHECK (locale IN ('ru', 'en')),
    UNIQUE(ohcat_id, locale)
);

-- User overheads
CREATE TABLE IF NOT EXISTS public.fi_overheads (
    user_id INTEGER NOT NULL,
    month DATE NOT NULL,
    ohcat_id INTEGER NOT NULL,
    platform VARCHAR(10) NOT NULL,
    amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT fi_overheads_month_check CHECK (date_trunc('month', month::TIMESTAMP) = month),
    CONSTRAINT fi_overheads_platform_check CHECK (platform IN ('wb', 'ozon')),
    PRIMARY KEY (user_id, month, ohcat_id, platform)
);

-- CRM/campaign management
CREATE TABLE IF NOT EXISTS public.crm_headers (
    advertid INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    crmname VARCHAR(255),
    crmtype INTEGER NOT NULL,
    crmstatus INTEGER NOT NULL,
    crmsps BOOLEAN,
    crmpt VARCHAR(255),
    pause_time TIME WITHOUT TIME ZONE,
    restart_time TIME WITHOUT TIME ZONE,
    active BOOLEAN,
    last_updated TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (advertid, user_id)
);

-- Prices
CREATE TABLE IF NOT EXISTS public.prices (
    nmid BIGINT PRIMARY KEY,
    price NUMERIC(10,2),
    discount NUMERIC(5,2),
    promocode NUMERIC(5,2),
    currentprice NUMERIC(10,2),
    dayprice NUMERIC(10,2),
    nightprice NUMERIC(10,2),
    daydisc NUMERIC(5,2),
    nightdisc NUMERIC(5,2),
    active CHAR(1)
);

-- Localization
CREATE TABLE IF NOT EXISTS public.localization (
    loctype INTEGER NOT NULL,
    colname VARCHAR(20) NOT NULL,
    locale CHAR(2) NOT NULL DEFAULT 'RU',
    value TEXT NOT NULL,
    PRIMARY KEY (loctype, colname, locale)
);

-- Logs
CREATE TABLE IF NOT EXISTS public.logs (
    log_date DATE,
    log_time TIME WITHOUT TIME ZONE,
    duration_ms INTEGER,
    function_name TEXT,
    message TEXT
);

-- ============================================================================
-- Foreign Keys (add only if they don't exist)
-- ============================================================================

DO $$ 
BEGIN
    -- User API keys foreign keys
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_user_api_keys_user') THEN
        ALTER TABLE public.user_api_keys ADD CONSTRAINT fk_user_api_keys_user 
            FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_user_api_keys_type') THEN
        ALTER TABLE public.user_api_keys ADD CONSTRAINT fk_user_api_keys_type 
            FOREIGN KEY (key_type) REFERENCES public.api_key_types(key_type);
    END IF;
    
    -- Goods foreign keys
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_goods_type_loc_type') THEN
        ALTER TABLE public.goods_type_loc ADD CONSTRAINT fk_goods_type_loc_type 
            FOREIGN KEY (goods_type_id) REFERENCES public.goods_type(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_goods_grp_type') THEN
        ALTER TABLE public.goods_grp ADD CONSTRAINT fk_goods_grp_type 
            FOREIGN KEY (goods_type_id) REFERENCES public.goods_type(id) ON DELETE SET NULL;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_goods_grp_loc_grp') THEN
        ALTER TABLE public.goods_grp_loc ADD CONSTRAINT fk_goods_grp_loc_grp 
            FOREIGN KEY (goods_grp_id) REFERENCES public.goods_grp(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_goods_grp') THEN
        ALTER TABLE public.goods ADD CONSTRAINT fk_goods_grp 
            FOREIGN KEY (goods_grp_id) REFERENCES public.goods_grp(id) ON DELETE SET NULL;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_photos_goods') THEN
        ALTER TABLE public.photos ADD CONSTRAINT fk_photos_goods 
            FOREIGN KEY (vendorcode) REFERENCES public.goods(vendorcode) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_cost_price_goods') THEN
        ALTER TABLE public.cost_price ADD CONSTRAINT fk_cost_price_goods 
            FOREIGN KEY (vendorcode) REFERENCES public.goods(vendorcode) ON DELETE CASCADE;
    END IF;
    
    -- Overhead foreign keys
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ohgrp_loc_grp') THEN
        ALTER TABLE public.fi_ohgrp_loc ADD CONSTRAINT fk_ohgrp_loc_grp 
            FOREIGN KEY (ohgrp_id) REFERENCES public.fi_ohgrp(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ohcat_grp') THEN
        ALTER TABLE public.fi_ohcat ADD CONSTRAINT fk_ohcat_grp 
            FOREIGN KEY (oh_grp_id) REFERENCES public.fi_ohgrp(id) ON DELETE SET NULL;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ohcat_loc_cat') THEN
        ALTER TABLE public.fi_ohcat_loc ADD CONSTRAINT fk_ohcat_loc_cat 
            FOREIGN KEY (ohcat_id) REFERENCES public.fi_ohcat(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_overheads_user') THEN
        ALTER TABLE public.fi_overheads ADD CONSTRAINT fk_overheads_user 
            FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_overheads_cat') THEN
        ALTER TABLE public.fi_overheads ADD CONSTRAINT fk_overheads_cat 
            FOREIGN KEY (ohcat_id) REFERENCES public.fi_ohcat(id) ON DELETE RESTRICT;
    END IF;
    
    -- CRM foreign keys
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_crm_user') THEN
        ALTER TABLE public.crm_headers ADD CONSTRAINT fk_crm_user 
            FOREIGN KEY (user_id) REFERENCES public.users(id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_crm_status') THEN
        ALTER TABLE public.crm_headers ADD CONSTRAINT fk_crm_status 
            FOREIGN KEY (crmstatus) REFERENCES public.crm_status(crmstatus);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_crm_type') THEN
        ALTER TABLE public.crm_headers ADD CONSTRAINT fk_crm_type 
            FOREIGN KEY (crmtype) REFERENCES public.crm_type(crmtype);
    END IF;
    
    -- Localization foreign key
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_localization_type') THEN
        ALTER TABLE public.localization ADD CONSTRAINT fk_localization_type 
            FOREIGN KEY (loctype) REFERENCES public.ltypes(loctype) ON DELETE RESTRICT;
    END IF;
END $$;

-- ============================================================================
-- Indexes (create if not exists - using conditional logic)
-- ============================================================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_goods_nmid') THEN
        CREATE INDEX idx_goods_nmid ON public.goods USING btree (nmid);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_goods_deleted') THEN
        CREATE INDEX idx_goods_deleted ON public.goods USING btree (deleted) WHERE deleted = TRUE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_goods_vendor_deleted') THEN
        CREATE INDEX idx_goods_vendor_deleted ON public.goods USING btree (vendorcode, deleted);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_goods_grp_id') THEN
        CREATE INDEX idx_goods_grp_id ON public.goods USING btree (goods_grp_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_cost_price_vendorcode') THEN
        CREATE INDEX idx_cost_price_vendorcode ON public.cost_price USING btree (vendorcode);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_cost_price_dates') THEN
        CREATE INDEX idx_cost_price_dates ON public.cost_price USING btree (vendorcode, beg_date, end_date);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_ohcat_oh_grp_id') THEN
        CREATE INDEX idx_ohcat_oh_grp_id ON public.fi_ohcat USING btree (oh_grp_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_ohcat_loc_ohcat') THEN
        CREATE INDEX idx_ohcat_loc_ohcat ON public.fi_ohcat_loc USING btree (ohcat_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_ohgrp_loc_ohgrp') THEN
        CREATE INDEX idx_ohgrp_loc_ohgrp ON public.fi_ohgrp_loc USING btree (ohgrp_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_overheads_user') THEN
        CREATE INDEX idx_overheads_user ON public.fi_overheads USING btree (user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_overheads_month') THEN
        CREATE INDEX idx_overheads_month ON public.fi_overheads USING btree (month);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_overheads_user_month') THEN
        CREATE INDEX idx_overheads_user_month ON public.fi_overheads USING btree (user_id, month);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_goods_grp_loc_grp') THEN
        CREATE INDEX idx_goods_grp_loc_grp ON public.goods_grp_loc USING btree (goods_grp_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_goods_grp_type_id') THEN
        CREATE INDEX idx_goods_grp_type_id ON public.goods_grp USING btree (goods_type_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_goods_type_loc_type') THEN
        CREATE INDEX idx_goods_type_loc_type ON public.goods_type_loc USING btree (goods_type_id);
    END IF;
END $$;

-- ============================================================================
-- Triggers (drop and recreate to ensure idempotency)
-- ============================================================================

DROP TRIGGER IF EXISTS update_cost_price_updated_at ON public.cost_price;
CREATE TRIGGER update_cost_price_updated_at
    BEFORE UPDATE ON public.cost_price
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_overheads_updated_at ON public.fi_overheads;
CREATE TRIGGER trigger_overheads_updated_at
    BEFORE UPDATE ON public.fi_overheads
    FOR EACH ROW
    EXECUTE FUNCTION public.update_overheads_updated_at();

DROP TRIGGER IF EXISTS campaign_update_trigger ON public.crm_headers;
CREATE TRIGGER campaign_update_trigger
    BEFORE UPDATE ON public.crm_headers
    FOR EACH ROW
    EXECUTE FUNCTION public.update_campaign_timestamp();

DROP TRIGGER IF EXISTS campaign_notify_trigger ON public.crm_headers;
CREATE TRIGGER campaign_notify_trigger
    AFTER UPDATE ON public.crm_headers
    FOR EACH ROW
    WHEN (NEW.active IS DISTINCT FROM OLD.active OR
          NEW.pause_time IS DISTINCT FROM OLD.pause_time OR
          NEW.restart_time IS DISTINCT FROM OLD.restart_time)
    EXECUTE FUNCTION public.notify_campaign_update();

-- ============================================================================
-- Views (OR REPLACE for idempotency)
-- ============================================================================

CREATE OR REPLACE VIEW public.goods_type_active_multilang AS
SELECT 
    t.id,
    t.active,
    COALESCE(ru.name, en.name, '') AS name_ru,
    COALESCE(ru.description, en.description, '') AS description_ru,
    COALESCE(en.name, ru.name, '') AS name_en,
    COALESCE(en.description, ru.description, '') AS description_en
FROM public.goods_type t
LEFT JOIN public.goods_type_loc ru ON t.id = ru.goods_type_id AND ru.locale = 'ru'
LEFT JOIN public.goods_type_loc en ON t.id = en.goods_type_id AND en.locale = 'en'
WHERE t.active = TRUE
ORDER BY t.id;

CREATE OR REPLACE VIEW public.goods_grp_active_multilang AS
SELECT 
    g.id,
    g.active,
    COALESCE(ru.name, en.name, '') AS name_ru,
    COALESCE(ru.description, en.description, '') AS description_ru,
    COALESCE(en.name, ru.name, '') AS name_en,
    COALESCE(en.description, ru.description, '') AS description_en,
    g.goods_type_id
FROM public.goods_grp g
LEFT JOIN public.goods_grp_loc ru ON g.id = ru.goods_grp_id AND ru.locale = 'ru'
LEFT JOIN public.goods_grp_loc en ON g.id = en.goods_grp_id AND en.locale = 'en'
WHERE g.active = TRUE
ORDER BY g.id;

CREATE OR REPLACE VIEW public.fi_ohgrp_active_multilang AS
SELECT 
    g.id,
    g.active,
    COALESCE(ru.name, en.name, '') AS name_ru,
    COALESCE(ru.description, en.description, '') AS description_ru,
    COALESCE(en.name, ru.name, '') AS name_en,
    COALESCE(en.description, ru.description, '') AS description_en
FROM public.fi_ohgrp g
LEFT JOIN public.fi_ohgrp_loc ru ON g.id = ru.ohgrp_id AND ru.locale = 'ru'
LEFT JOIN public.fi_ohgrp_loc en ON g.id = en.ohgrp_id AND en.locale = 'en'
WHERE g.active = TRUE
ORDER BY g.id;

CREATE OR REPLACE VIEW public.fi_ohcat_active_multilang AS
SELECT 
    c.id,
    c.active,
    COALESCE(ru.name, en.name, '') AS name_ru,
    COALESCE(ru.description, en.description, '') AS description_ru,
    COALESCE(en.name, ru.name, '') AS name_en,
    COALESCE(en.description, ru.description, '') AS description_en,
    c.oh_grp_id
FROM public.fi_ohcat c
LEFT JOIN public.fi_ohcat_loc ru ON c.id = ru.ohcat_id AND ru.locale = 'ru'
LEFT JOIN public.fi_ohcat_loc en ON c.id = en.ohcat_id AND en.locale = 'en'
WHERE c.active = TRUE
ORDER BY c.id;

CREATE OR REPLACE VIEW public.product_data AS
SELECT 
    g.card_photo,
    g.title,
    g.vendorcode,
    g.nmid,
    g.wbvol,
    g.ozid,
    g.ozvol,
    g.imtid,
    cp.cost_value AS current_cost,
    CURRENT_DATE AS change_date,
    g.deleted,
    COALESCE(gt.name_ru, '') AS goods_type_name,
    g.goods_grp_id,
    COALESCE(gg.name_ru, '') AS goods_grp_name
FROM public.goods g
LEFT JOIN public.cost_price cp ON cp.vendorcode = g.vendorcode AND cp.end_date IS NULL
LEFT JOIN public.goods_grp_active_multilang gg ON g.goods_grp_id = gg.id
LEFT JOIN public.goods_type_active_multilang gt ON gg.goods_type_id = gt.id
ORDER BY g.vendorcode;

-- ============================================================================
-- Helper functions (OR REPLACE for idempotency)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_goods_type(
    p_name_ru VARCHAR,
    p_description_ru TEXT,
    p_name_en VARCHAR DEFAULT NULL,
    p_description_en TEXT DEFAULT NULL,
    p_active BOOLEAN DEFAULT TRUE
)
RETURNS TABLE(
    id INTEGER,
    active BOOLEAN,
    name_ru VARCHAR,
    description_ru TEXT,
    name_en VARCHAR,
    description_en TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_goods_type_id INTEGER;
BEGIN
    INSERT INTO goods_type (active) VALUES (p_active) RETURNING id INTO v_goods_type_id;
    
    INSERT INTO goods_type_loc (goods_type_id, locale, name, description)
    VALUES (v_goods_type_id, 'ru', p_name_ru, COALESCE(p_description_ru, ''));
    
    IF p_name_en IS NOT NULL AND p_name_en != '' THEN
        INSERT INTO goods_type_loc (goods_type_id, locale, name, description)
        VALUES (v_goods_type_id, 'en', p_name_en, COALESCE(p_description_en, p_description_ru, ''));
    END IF;
    
    RETURN QUERY
    SELECT 
        t.id,
        t.active,
        COALESCE(ru.name, '')::VARCHAR(255),
        COALESCE(ru.description, ''),
        COALESCE(en.name, '')::VARCHAR(255),
        COALESCE(en.description, '')
    FROM goods_type t
    LEFT JOIN goods_type_loc ru ON t.id = ru.goods_type_id AND ru.locale = 'ru'
    LEFT JOIN goods_type_loc en ON t.id = en.goods_type_id AND en.locale = 'en'
    WHERE t.id = v_goods_type_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_goods_grp(
    p_name_ru VARCHAR,
    p_description_ru TEXT,
    p_name_en VARCHAR DEFAULT NULL,
    p_description_en TEXT DEFAULT NULL,
    p_active BOOLEAN DEFAULT TRUE,
    p_goods_type_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
    id INTEGER,
    active BOOLEAN,
    name_ru VARCHAR,
    description_ru TEXT,
    name_en VARCHAR,
    description_en TEXT,
    goods_type_id INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
    v_goods_grp_id INTEGER;
BEGIN
    INSERT INTO goods_grp (active, goods_type_id) VALUES (p_active, p_goods_type_id)
    RETURNING id INTO v_goods_grp_id;
    
    INSERT INTO goods_grp_loc (goods_grp_id, locale, name, description)
    VALUES (v_goods_grp_id, 'ru', p_name_ru, COALESCE(p_description_ru, ''));
    
    IF p_name_en IS NOT NULL AND p_name_en != '' THEN
        INSERT INTO goods_grp_loc (goods_grp_id, locale, name, description)
        VALUES (v_goods_grp_id, 'en', p_name_en, COALESCE(p_description_en, p_description_ru, ''));
    END IF;
    
    RETURN QUERY
    SELECT 
        g.id,
        g.active,
        COALESCE(ru.name, '')::VARCHAR(255),
        COALESCE(ru.description, ''),
        COALESCE(en.name, '')::VARCHAR(255),
        COALESCE(en.description, ''),
        g.goods_type_id
    FROM goods_grp g
    LEFT JOIN goods_grp_loc ru ON g.id = ru.goods_grp_id AND ru.locale = 'ru'
    LEFT JOIN goods_grp_loc en ON g.id = en.goods_grp_id AND en.locale = 'en'
    WHERE g.id = v_goods_grp_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_ohgrp(
    p_name_ru VARCHAR,
    p_description_ru TEXT,
    p_name_en VARCHAR DEFAULT NULL,
    p_description_en TEXT DEFAULT NULL,
    p_active BOOLEAN DEFAULT TRUE
)
RETURNS TABLE(
    id INTEGER,
    active BOOLEAN,
    name_ru VARCHAR,
    description_ru TEXT,
    name_en VARCHAR,
    description_en TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_ohgrp_id INTEGER;
BEGIN
    INSERT INTO fi_ohgrp (active) VALUES (p_active) RETURNING id INTO v_ohgrp_id;
    
    INSERT INTO fi_ohgrp_loc (ohgrp_id, locale, name, description)
    VALUES (v_ohgrp_id, 'ru', p_name_ru, COALESCE(p_description_ru, ''));
    
    IF p_name_en IS NOT NULL AND p_name_en != '' THEN
        INSERT INTO fi_ohgrp_loc (ohgrp_id, locale, name, description)
        VALUES (v_ohgrp_id, 'en', p_name_en, COALESCE(p_description_en, p_description_ru, ''));
    END IF;
    
    RETURN QUERY
    SELECT 
        g.id,
        g.active,
        COALESCE(ru.name, '')::VARCHAR(255),
        COALESCE(ru.description, ''),
        COALESCE(en.name, '')::VARCHAR(255),
        COALESCE(en.description, '')
    FROM fi_ohgrp g
    LEFT JOIN fi_ohgrp_loc ru ON g.id = ru.ohgrp_id AND ru.locale = 'ru'
    LEFT JOIN fi_ohgrp_loc en ON g.id = en.ohgrp_id AND en.locale = 'en'
    WHERE g.id = v_ohgrp_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_ohcat(
    p_name_ru VARCHAR,
    p_description_ru TEXT,
    p_name_en VARCHAR DEFAULT NULL,
    p_description_en TEXT DEFAULT NULL,
    p_active BOOLEAN DEFAULT TRUE,
    p_oh_grp_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
    id INTEGER,
    active BOOLEAN,
    name_ru VARCHAR,
    description_ru TEXT,
    name_en VARCHAR,
    description_en TEXT,
    oh_grp_id INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
    v_ohcat_id INTEGER;
BEGIN
    INSERT INTO fi_ohcat (active, oh_grp_id) VALUES (p_active, p_oh_grp_id)
    RETURNING id INTO v_ohcat_id;
    
    INSERT INTO fi_ohcat_loc (ohcat_id, locale, name, description)
    VALUES (v_ohcat_id, 'ru', p_name_ru, COALESCE(p_description_ru, ''));
    
    IF p_name_en IS NOT NULL AND p_name_en != '' THEN
        INSERT INTO fi_ohcat_loc (ohcat_id, locale, name, description)
        VALUES (v_ohcat_id, 'en', p_name_en, COALESCE(p_description_en, p_description_ru, ''));
    END IF;
    
    RETURN QUERY
    SELECT 
        c.id,
        c.active,
        COALESCE(ru.name, '')::VARCHAR(255),
        COALESCE(ru.description, ''),
        COALESCE(en.name, '')::VARCHAR(255),
        COALESCE(en.description, ''),
        c.oh_grp_id
    FROM fi_ohcat c
    LEFT JOIN fi_ohcat_loc ru ON c.id = ru.ohcat_id AND ru.locale = 'ru'
    LEFT JOIN fi_ohcat_loc en ON c.id = en.ohcat_id AND en.locale = 'en'
    WHERE c.id = v_ohcat_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_overheads_4months(
    p_user_id INTEGER,
    p_month DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(
    oh_month DATE,
    ohcat_id INTEGER,
    ohcat_name VARCHAR,
    oh_grp_id INTEGER,
    platform VARCHAR,
    oh_amount NUMERIC
)
LANGUAGE sql STABLE AS $$
    WITH params AS (
        SELECT date_trunc('month', COALESCE(p_month, CURRENT_DATE))::DATE as norm_month
    ),
    months AS (
        SELECT generate_series(
            (SELECT norm_month - INTERVAL '1 month' FROM params),
            (SELECT norm_month + INTERVAL '2 months' FROM params),
            '1 month'
        )::DATE AS month
    ),
    categories AS (
        SELECT c.id, c.name_ru, c.oh_grp_id
        FROM fi_ohcat_active_multilang c
    ),
    platforms AS (
        SELECT unnest(ARRAY['wb', 'ozon']) AS platform
    )
    SELECT 
        m.month,
        cat.id,
        cat.name_ru,
        cat.oh_grp_id,
        p.platform,
        COALESCE(o.amount, 0) AS oh_amount
    FROM months m
    CROSS JOIN categories cat
    CROSS JOIN platforms p
    LEFT JOIN fi_overheads o ON 
        o.user_id = p_user_id
        AND o.month = m.month
        AND o.ohcat_id = cat.id
        AND o.platform = p.platform
    ORDER BY m.month, p.platform, cat.id;
$$;

CREATE OR REPLACE FUNCTION public.update_cost_price(
    p_vendorcode VARCHAR,
    p_new_cost NUMERIC,
    p_start_date DATE
)
RETURNS TABLE(
    status TEXT,
    message TEXT,
    old_cost NUMERIC,
    new_cost NUMERIC,
    effective_from DATE,
    effective_to DATE
)
LANGUAGE plpgsql AS $$
DECLARE
    v_current_cost NUMERIC(12,2);
    v_current_beg_date DATE;
    v_previous_end_date DATE;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.goods WHERE vendorcode = p_vendorcode) THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Product with vendorcode ' || p_vendorcode || ' not found'::TEXT,
            NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    SELECT cost_value, beg_date INTO v_current_cost, v_current_beg_date
    FROM public.cost_price
    WHERE vendorcode = p_vendorcode AND end_date IS NULL
    FOR UPDATE;
    
    IF v_current_cost IS NULL THEN
        INSERT INTO public.cost_price (vendorcode, cost_value, beg_date, end_date)
        VALUES (p_vendorcode, p_new_cost, p_start_date, NULL);
        
        RETURN QUERY SELECT 
            'SUCCESS'::TEXT, 
            'New cost price created (no active record existed)'::TEXT,
            NULL::NUMERIC, p_new_cost, p_start_date, NULL::DATE;
        RETURN;
    END IF;
    
    IF v_current_cost = p_new_cost THEN
        RETURN QUERY SELECT 
            'WARNING'::TEXT, 
            'Cost price unchanged, update not required'::TEXT,
            v_current_cost, p_new_cost, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    v_previous_end_date := p_start_date - INTERVAL '1 day';
    
    UPDATE public.cost_price
    SET end_date = v_previous_end_date,
        updated_at = CURRENT_TIMESTAMP
    WHERE vendorcode = p_vendorcode AND end_date IS NULL;
    
    INSERT INTO public.cost_price (vendorcode, cost_value, beg_date, end_date)
    VALUES (p_vendorcode, p_new_cost, p_start_date, NULL);
    
    RETURN QUERY SELECT 
        'SUCCESS'::TEXT, 
        'Cost price successfully updated'::TEXT,
        v_current_cost, p_new_cost, p_start_date, v_previous_end_date;
        
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Error: ' || SQLERRM::TEXT,
            NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
END;
$$;