--
-- PostgreSQL database dump
--

\restrict QrwaFjl3M5Nz6NdbCg2evtgwlldvNEnJjB7HZ3OCFkaUa6ELK25Upgq1iYOlbjy

-- Dumped from database version 18.0
-- Dumped by pg_dump version 18.0

-- Started on 2026-06-11 11:01:48

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 4 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- TOC entry 5271 (class 0 OID 0)
-- Dependencies: 4
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 280 (class 1255 OID 17032)
-- Name: create_goods_grp(character varying, text, character varying, text, boolean, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_goods_grp(p_name_ru character varying, p_description_ru text, p_name_en character varying DEFAULT NULL::character varying, p_description_en text DEFAULT NULL::text, p_active boolean DEFAULT true, p_goods_type_id integer DEFAULT NULL::integer) RETURNS TABLE(id integer, active boolean, name_ru character varying, description_ru text, name_en character varying, description_en text, goods_type_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_goods_grp_id INTEGER;
BEGIN
    -- 1. Вставляем в основную таблицу
    INSERT INTO goods_grp (active, goods_type_id) VALUES (p_active, p_goods_type_id);
    
    -- 2. Получаем последний ID
    SELECT lastval() INTO v_goods_grp_id;
    
    -- 3. Вставляем русскую локализацию
    INSERT INTO goods_grp_loc (goods_grp_id, locale, name, description)
    VALUES (v_goods_grp_id, 'ru', p_name_ru, COALESCE(p_description_ru, ''));
    
    -- 4. Вставляем английскую локализацию (если есть)
    IF p_name_en IS NOT NULL AND p_name_en != '' THEN
        INSERT INTO goods_grp_loc (goods_grp_id, locale, name, description)
        VALUES (v_goods_grp_id, 'en', p_name_en, COALESCE(p_description_en, p_description_ru, ''));
    END IF;
    
    -- 5. Возвращаем результат
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


ALTER FUNCTION public.create_goods_grp(p_name_ru character varying, p_description_ru text, p_name_en character varying, p_description_en text, p_active boolean, p_goods_type_id integer) OWNER TO postgres;

--
-- TOC entry 5272 (class 0 OID 0)
-- Dependencies: 280
-- Name: FUNCTION create_goods_grp(p_name_ru character varying, p_description_ru text, p_name_en character varying, p_description_en text, p_active boolean, p_goods_type_id integer); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.create_goods_grp(p_name_ru character varying, p_description_ru text, p_name_en character varying, p_description_en text, p_active boolean, p_goods_type_id integer) IS 'Создание новой группы товаров с локализациями и типом товара';


--
-- TOC entry 279 (class 1255 OID 17024)
-- Name: create_goods_type(character varying, text, character varying, text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_goods_type(p_name_ru character varying, p_description_ru text, p_name_en character varying DEFAULT NULL::character varying, p_description_en text DEFAULT NULL::text, p_active boolean DEFAULT true) RETURNS TABLE(id integer, active boolean, name_ru character varying, description_ru text, name_en character varying, description_en text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_goods_type_id INTEGER;
BEGIN
    -- 1. Вставляем в основную таблицу
    INSERT INTO goods_type (active) VALUES (p_active);
    
    -- 2. Получаем последний ID
    SELECT lastval() INTO v_goods_type_id;
    
    -- 3. Вставляем русскую локализацию
    INSERT INTO goods_type_loc (goods_type_id, locale, name, description)
    VALUES (v_goods_type_id, 'ru', p_name_ru, COALESCE(p_description_ru, ''));
    
    -- 4. Вставляем английскую локализацию (если есть)
    IF p_name_en IS NOT NULL AND p_name_en != '' THEN
        INSERT INTO goods_type_loc (goods_type_id, locale, name, description)
        VALUES (v_goods_type_id, 'en', p_name_en, COALESCE(p_description_en, p_description_ru, ''));
    END IF;
    
    -- 5. Возвращаем результат
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


ALTER FUNCTION public.create_goods_type(p_name_ru character varying, p_description_ru text, p_name_en character varying, p_description_en text, p_active boolean) OWNER TO postgres;

--
-- TOC entry 5273 (class 0 OID 0)
-- Dependencies: 279
-- Name: FUNCTION create_goods_type(p_name_ru character varying, p_description_ru text, p_name_en character varying, p_description_en text, p_active boolean); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.create_goods_type(p_name_ru character varying, p_description_ru text, p_name_en character varying, p_description_en text, p_active boolean) IS 'Создание нового типа товаров с локализациями';


--
-- TOC entry 278 (class 1255 OID 16944)
-- Name: create_ohcat(character varying, text, character varying, text, boolean, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_ohcat(p_name_ru character varying, p_description_ru text, p_name_en character varying DEFAULT NULL::character varying, p_description_en text DEFAULT NULL::text, p_active boolean DEFAULT true, p_oh_grp_id integer DEFAULT NULL::integer) RETURNS TABLE(id integer, active boolean, name_ru character varying, description_ru text, name_en character varying, description_en text, oh_grp_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_ohcat_id INTEGER;
BEGIN
    INSERT INTO fi_ohcat (active, oh_grp_id) VALUES (p_active, p_oh_grp_id);
    
    SELECT lastval() INTO v_ohcat_id;
    
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


ALTER FUNCTION public.create_ohcat(p_name_ru character varying, p_description_ru text, p_name_en character varying, p_description_en text, p_active boolean, p_oh_grp_id integer) OWNER TO postgres;

--
-- TOC entry 277 (class 1255 OID 16925)
-- Name: create_ohgrp(character varying, text, character varying, text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_ohgrp(p_name_ru character varying, p_description_ru text, p_name_en character varying DEFAULT NULL::character varying, p_description_en text DEFAULT NULL::text, p_active boolean DEFAULT true) RETURNS TABLE(id integer, active boolean, name_ru character varying, description_ru text, name_en character varying, description_en text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_ohgrp_id INTEGER;
BEGIN
    -- 1. Вставляем в основную таблицу
    INSERT INTO fi_ohgrp (active) VALUES (p_active);
    
    -- 2. Получаем последний ID для текущей сессии
    SELECT lastval() INTO v_ohgrp_id;
    
    -- 3. Вставляем русскую локализацию
    INSERT INTO fi_ohgrp_loc (ohgrp_id, locale, name, description)
    VALUES (v_ohgrp_id, 'ru', p_name_ru, COALESCE(p_description_ru, ''));
    
    -- 4. Вставляем английскую локализацию (если есть)
    IF p_name_en IS NOT NULL AND p_name_en != '' THEN
        INSERT INTO fi_ohgrp_loc (ohgrp_id, locale, name, description)
        VALUES (v_ohgrp_id, 'en', p_name_en, COALESCE(p_description_en, p_description_ru, ''));
    END IF;
    
    -- 5. Возвращаем результат
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


ALTER FUNCTION public.create_ohgrp(p_name_ru character varying, p_description_ru text, p_name_en character varying, p_description_en text, p_active boolean) OWNER TO postgres;

--
-- TOC entry 275 (class 1255 OID 17083)
-- Name: get_overheads_4months(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_overheads_4months(p_user_id integer, p_month date DEFAULT CURRENT_DATE) RETURNS TABLE(oh_month date, ohcat_id integer, ohcat_name character varying, oh_grp_id integer, platform character varying, oh_amount numeric)
    LANGUAGE sql STABLE
    AS $$
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
        SELECT 
            c.id, 
            c.name_ru,
            c.oh_grp_id
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


ALTER FUNCTION public.get_overheads_4months(p_user_id integer, p_month date) OWNER TO postgres;

--
-- TOC entry 258 (class 1255 OID 16389)
-- Name: notify_campaign_update(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.notify_campaign_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
  NEW.last_updated = NOW();
  
  -- Если изменилось время или статус активности
  IF NEW.active IS DISTINCT FROM OLD.active OR
     NEW.pause_time IS DISTINCT FROM OLD.pause_time OR
     NEW.restart_time IS DISTINCT FROM OLD.restart_time THEN
    
    -- Отправляем уведомление (для сервера)
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
END;$$;


ALTER FUNCTION public.notify_campaign_update() OWNER TO postgres;

--
-- TOC entry 259 (class 1255 OID 16390)
-- Name: update_campaign_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_campaign_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.last_updated = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_campaign_timestamp() OWNER TO postgres;

--
-- TOC entry 274 (class 1255 OID 16689)
-- Name: update_cost_price(character varying, numeric, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_cost_price(p_vendorcode character varying, p_new_cost numeric, p_start_date date) RETURNS TABLE(status text, message text, old_cost numeric, new_cost numeric, effective_from date, effective_to date)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_current_cost NUMERIC(12,2);
    v_current_beg_date DATE;
    v_previous_end_date DATE;
BEGIN
    -- Проверяем существование товара
    IF NOT EXISTS (SELECT 1 FROM public.goods WHERE vendorcode = p_vendorcode) THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Товар с vendorcode ' || p_vendorcode || ' не найден'::TEXT,
            NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    
    -- Находим текущую активную себестоимость
    SELECT cost_value, beg_date INTO v_current_cost, v_current_beg_date
    FROM public.cost_price
    WHERE vendorcode = p_vendorcode AND end_date IS NULL
    FOR UPDATE;
    
    -- Если текущей себестоимости нет, создаем первую запись
    IF v_current_cost IS NULL THEN
        INSERT INTO public.cost_price (vendorcode, cost_value, beg_date, end_date)
        VALUES (p_vendorcode, p_new_cost, p_start_date, NULL);
        
        RETURN QUERY SELECT 
            'SUCCESS'::TEXT, 
            'Создана новая себестоимость (активная запись отсутствовала)'::TEXT,
            NULL::NUMERIC, p_new_cost, p_start_date, NULL::DATE;
        RETURN;
    END IF;
    
    -- Проверяем, не пытаемся ли установить ту же себестоимость
    IF v_current_cost = p_new_cost THEN
        RETURN QUERY SELECT 
            'WARNING'::TEXT, 
            'Себестоимость не изменилась, обновление не требуется'::TEXT,
            v_current_cost, p_new_cost, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Основная логика: закрываем текущий период и создаем новый
    v_previous_end_date := p_start_date - INTERVAL '1 day';
    
    -- Обновляем текущую запись (закрываем период)
    UPDATE public.cost_price
    SET end_date = v_previous_end_date,
        updated_at = CURRENT_TIMESTAMP
    WHERE vendorcode = p_vendorcode AND end_date IS NULL;
    
    -- Создаем новую запись с новой себестоимостью
    INSERT INTO public.cost_price (vendorcode, cost_value, beg_date, end_date)
    VALUES (p_vendorcode, p_new_cost, p_start_date, NULL);
    
    -- Возвращаем результат
    RETURN QUERY SELECT 
        'SUCCESS'::TEXT, 
        'Себестоимость успешно обновлена'::TEXT,
        v_current_cost, p_new_cost, p_start_date, v_previous_end_date;
        
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Ошибка: ' || SQLERRM::TEXT,
            NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
END;
$$;


ALTER FUNCTION public.update_cost_price(p_vendorcode character varying, p_new_cost numeric, p_start_date date) OWNER TO postgres;

--
-- TOC entry 260 (class 1255 OID 16391)
-- Name: update_ohcat_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_ohcat_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_ohcat_timestamp() OWNER TO postgres;

--
-- TOC entry 261 (class 1255 OID 16392)
-- Name: update_overhead_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_overhead_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_overhead_timestamp() OWNER TO postgres;

--
-- TOC entry 276 (class 1255 OID 17080)
-- Name: update_overheads_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_overheads_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_overheads_updated_at() OWNER TO postgres;

--
-- TOC entry 262 (class 1255 OID 16684)
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 219 (class 1259 OID 16393)
-- Name: api_key_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.api_key_types (
    key_type smallint NOT NULL,
    key_text character varying(20)[] NOT NULL
);


ALTER TABLE public.api_key_types OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 16662)
-- Name: cost_price; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cost_price (
    id_cost integer NOT NULL,
    vendorcode character varying(10) NOT NULL,
    cost_value numeric(12,2) NOT NULL,
    beg_date date NOT NULL,
    end_date date,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT cost_price_dates_check CHECK (((end_date IS NULL) OR (beg_date <= end_date)))
);


ALTER TABLE public.cost_price OWNER TO postgres;

--
-- TOC entry 5274 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE cost_price; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.cost_price IS 'История себестоимости товаров';


--
-- TOC entry 5275 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN cost_price.vendorcode; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.cost_price.vendorcode IS 'Артикул товара';


--
-- TOC entry 5276 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN cost_price.cost_value; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.cost_price.cost_value IS 'Себестоимость';


--
-- TOC entry 5277 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN cost_price.beg_date; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.cost_price.beg_date IS 'Дата начала действия';


--
-- TOC entry 5278 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN cost_price.end_date; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.cost_price.end_date IS 'Дата окончания действия (NULL - действует сейчас)';


--
-- TOC entry 231 (class 1259 OID 16661)
-- Name: cost_price_id_cost_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cost_price_id_cost_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cost_price_id_cost_seq OWNER TO postgres;

--
-- TOC entry 5279 (class 0 OID 0)
-- Dependencies: 231
-- Name: cost_price_id_cost_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cost_price_id_cost_seq OWNED BY public.cost_price.id_cost;


--
-- TOC entry 220 (class 1259 OID 16406)
-- Name: crm_headers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.crm_headers (
    advertid integer NOT NULL,
    crmname character varying(255),
    crmtype integer NOT NULL,
    crmstatus integer NOT NULL,
    crmsps boolean,
    crmpt character varying(255),
    pause_time time without time zone,
    restart_time time without time zone,
    active boolean,
    last_updated timestamp without time zone DEFAULT now(),
    user_id integer NOT NULL
);


ALTER TABLE public.crm_headers OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16416)
-- Name: crm_status; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.crm_status (
    crmstatus integer NOT NULL,
    description character varying(40) NOT NULL
);


ALTER TABLE public.crm_status OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 16421)
-- Name: crm_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.crm_type (
    crmtype integer NOT NULL,
    description character varying(60) NOT NULL
);


ALTER TABLE public.crm_type OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 16807)
-- Name: fi_ohcat; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fi_ohcat (
    id integer NOT NULL,
    active boolean DEFAULT true NOT NULL,
    oh_grp_id integer
);


ALTER TABLE public.fi_ohcat OWNER TO postgres;

--
-- TOC entry 5280 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN fi_ohcat.oh_grp_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.fi_ohcat.oh_grp_id IS 'ID группы накладных расходов';


--
-- TOC entry 239 (class 1259 OID 16817)
-- Name: fi_ohcat_loc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fi_ohcat_loc (
    id integer NOT NULL,
    ohcat_id integer NOT NULL,
    locale character varying(2) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    CONSTRAINT fi_ohcat_loc_locale_check CHECK (((locale)::text = ANY ((ARRAY['ru'::character varying, 'en'::character varying])::text[])))
);


ALTER TABLE public.fi_ohcat_loc OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 16939)
-- Name: fi_ohcat_active_multilang; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.fi_ohcat_active_multilang AS
 SELECT c.id,
    c.active,
    COALESCE(ru.name, en.name, ''::character varying) AS name_ru,
    COALESCE(ru.description, en.description, ''::text) AS description_ru,
    COALESCE(en.name, ru.name, ''::character varying) AS name_en,
    COALESCE(en.description, ru.description, ''::text) AS description_en,
    c.oh_grp_id
   FROM ((public.fi_ohcat c
     LEFT JOIN public.fi_ohcat_loc ru ON (((c.id = ru.ohcat_id) AND ((ru.locale)::text = 'ru'::text))))
     LEFT JOIN public.fi_ohcat_loc en ON (((c.id = en.ohcat_id) AND ((en.locale)::text = 'en'::text))))
  WHERE (c.active = true)
  ORDER BY c.id;


ALTER VIEW public.fi_ohcat_active_multilang OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 16806)
-- Name: fi_ohcat_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fi_ohcat_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fi_ohcat_id_seq OWNER TO postgres;

--
-- TOC entry 5281 (class 0 OID 0)
-- Dependencies: 236
-- Name: fi_ohcat_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fi_ohcat_id_seq OWNED BY public.fi_ohcat.id;


--
-- TOC entry 238 (class 1259 OID 16816)
-- Name: fi_ohcat_loc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fi_ohcat_loc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fi_ohcat_loc_id_seq OWNER TO postgres;

--
-- TOC entry 5282 (class 0 OID 0)
-- Dependencies: 238
-- Name: fi_ohcat_loc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fi_ohcat_loc_id_seq OWNED BY public.fi_ohcat_loc.id;


--
-- TOC entry 241 (class 1259 OID 16889)
-- Name: fi_ohgrp; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fi_ohgrp (
    id integer NOT NULL,
    active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.fi_ohgrp OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 16899)
-- Name: fi_ohgrp_loc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fi_ohgrp_loc (
    id integer NOT NULL,
    ohgrp_id integer NOT NULL,
    locale character varying(2) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    CONSTRAINT fi_ohgrp_loc_locale_check CHECK (((locale)::text = ANY ((ARRAY['ru'::character varying, 'en'::character varying])::text[])))
);


ALTER TABLE public.fi_ohgrp_loc OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 16920)
-- Name: fi_ohgrp_active_multilang; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.fi_ohgrp_active_multilang AS
 SELECT g.id,
    g.active,
    COALESCE(ru.name, en.name, ''::character varying) AS name_ru,
    COALESCE(ru.description, en.description, ''::text) AS description_ru,
    COALESCE(en.name, ru.name, ''::character varying) AS name_en,
    COALESCE(en.description, ru.description, ''::text) AS description_en
   FROM ((public.fi_ohgrp g
     LEFT JOIN public.fi_ohgrp_loc ru ON (((g.id = ru.ohgrp_id) AND ((ru.locale)::text = 'ru'::text))))
     LEFT JOIN public.fi_ohgrp_loc en ON (((g.id = en.ohgrp_id) AND ((en.locale)::text = 'en'::text))))
  WHERE (g.active = true)
  ORDER BY g.id;


ALTER VIEW public.fi_ohgrp_active_multilang OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 16888)
-- Name: fi_ohgrp_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fi_ohgrp_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fi_ohgrp_id_seq OWNER TO postgres;

--
-- TOC entry 5283 (class 0 OID 0)
-- Dependencies: 240
-- Name: fi_ohgrp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fi_ohgrp_id_seq OWNED BY public.fi_ohgrp.id;


--
-- TOC entry 242 (class 1259 OID 16898)
-- Name: fi_ohgrp_loc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fi_ohgrp_loc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fi_ohgrp_loc_id_seq OWNER TO postgres;

--
-- TOC entry 5284 (class 0 OID 0)
-- Dependencies: 242
-- Name: fi_ohgrp_loc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fi_ohgrp_loc_id_seq OWNED BY public.fi_ohgrp_loc.id;


--
-- TOC entry 257 (class 1259 OID 17050)
-- Name: fi_overheads; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fi_overheads (
    user_id integer NOT NULL,
    month date NOT NULL,
    ohcat_id integer NOT NULL,
    platform character varying(10) NOT NULL,
    amount numeric(12,2) DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT fi_overheads_month_check CHECK ((date_trunc('month'::text, (month)::timestamp with time zone) = month)),
    CONSTRAINT fi_overheads_platform_check CHECK (((platform)::text = ANY ((ARRAY['wb'::character varying, 'ozon'::character varying])::text[])))
);


ALTER TABLE public.fi_overheads OWNER TO postgres;

--
-- TOC entry 5285 (class 0 OID 0)
-- Dependencies: 257
-- Name: TABLE fi_overheads; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.fi_overheads IS 'Накладные расходы пользователей';


--
-- TOC entry 5286 (class 0 OID 0)
-- Dependencies: 257
-- Name: COLUMN fi_overheads.user_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.fi_overheads.user_id IS 'ID пользователя (ссылка на users)';


--
-- TOC entry 5287 (class 0 OID 0)
-- Dependencies: 257
-- Name: COLUMN fi_overheads.month; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.fi_overheads.month IS 'Месяц периода (первое число месяца)';


--
-- TOC entry 5288 (class 0 OID 0)
-- Dependencies: 257
-- Name: COLUMN fi_overheads.ohcat_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.fi_overheads.ohcat_id IS 'ID категории накладных расходов';


--
-- TOC entry 5289 (class 0 OID 0)
-- Dependencies: 257
-- Name: COLUMN fi_overheads.platform; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.fi_overheads.platform IS 'Площадка: wb или ozon';


--
-- TOC entry 5290 (class 0 OID 0)
-- Dependencies: 257
-- Name: COLUMN fi_overheads.amount; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.fi_overheads.amount IS 'Сумма накладных расходов';


--
-- TOC entry 235 (class 1259 OID 16793)
-- Name: gen_platforms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.gen_platforms (
    id integer NOT NULL,
    code character varying(10) NOT NULL,
    name character varying(50) NOT NULL,
    active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.gen_platforms OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 16792)
-- Name: gen_platforms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.gen_platforms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.gen_platforms_id_seq OWNER TO postgres;

--
-- TOC entry 5291 (class 0 OID 0)
-- Dependencies: 234
-- Name: gen_platforms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.gen_platforms_id_seq OWNED BY public.gen_platforms.id;


--
-- TOC entry 230 (class 1259 OID 16653)
-- Name: goods; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.goods (
    vendorcode character varying(10) CONSTRAINT goods_new_vendorcode_not_null NOT NULL,
    nmid integer,
    ozid character varying(12),
    imtid integer,
    subjectid integer,
    subjectname text,
    brand character varying(20),
    title character varying(100),
    deleted boolean,
    wbvol integer,
    ozvol integer,
    card_photo text,
    goods_grp_id integer
);


ALTER TABLE public.goods OWNER TO postgres;

--
-- TOC entry 5292 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE goods; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.goods IS 'Таблица товаров';


--
-- TOC entry 5293 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN goods.vendorcode; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.goods.vendorcode IS 'Артикул товара (первичный ключ)';


--
-- TOC entry 5294 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN goods.nmid; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.goods.nmid IS 'Номер товара Wildberries';


--
-- TOC entry 5295 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN goods.ozid; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.goods.ozid IS 'Идентификатор Ozon';


--
-- TOC entry 5296 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN goods.card_photo; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.goods.card_photo IS 'Ссылка на большое фото товара (карточка)';


--
-- TOC entry 5297 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN goods.goods_grp_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.goods.goods_grp_id IS 'ID группы товаров (ссылка на goods_grp)';


--
-- TOC entry 247 (class 1259 OID 16950)
-- Name: goods_grp; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.goods_grp (
    id integer NOT NULL,
    active boolean DEFAULT true NOT NULL,
    goods_type_id integer
);


ALTER TABLE public.goods_grp OWNER TO postgres;

--
-- TOC entry 5298 (class 0 OID 0)
-- Dependencies: 247
-- Name: TABLE goods_grp; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.goods_grp IS 'Группы товаров';


--
-- TOC entry 5299 (class 0 OID 0)
-- Dependencies: 247
-- Name: COLUMN goods_grp.goods_type_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.goods_grp.goods_type_id IS 'ID типа товара (ссылка на goods_type)';


--
-- TOC entry 249 (class 1259 OID 16960)
-- Name: goods_grp_loc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.goods_grp_loc (
    id integer NOT NULL,
    goods_grp_id integer NOT NULL,
    locale character varying(2) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    CONSTRAINT goods_grp_loc_locale_check CHECK (((locale)::text = ANY ((ARRAY['ru'::character varying, 'en'::character varying])::text[])))
);


ALTER TABLE public.goods_grp_loc OWNER TO postgres;

--
-- TOC entry 5300 (class 0 OID 0)
-- Dependencies: 249
-- Name: TABLE goods_grp_loc; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.goods_grp_loc IS 'Локализация групп товаров';


--
-- TOC entry 250 (class 1259 OID 16981)
-- Name: goods_grp_active_multilang; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.goods_grp_active_multilang AS
 SELECT g.id,
    g.active,
    COALESCE(ru.name, en.name, ''::character varying) AS name_ru,
    COALESCE(ru.description, en.description, ''::text) AS description_ru,
    COALESCE(en.name, ru.name, ''::character varying) AS name_en,
    COALESCE(en.description, ru.description, ''::text) AS description_en,
    g.goods_type_id
   FROM ((public.goods_grp g
     LEFT JOIN public.goods_grp_loc ru ON (((g.id = ru.goods_grp_id) AND ((ru.locale)::text = 'ru'::text))))
     LEFT JOIN public.goods_grp_loc en ON (((g.id = en.goods_grp_id) AND ((en.locale)::text = 'en'::text))))
  WHERE (g.active = true)
  ORDER BY g.id;


ALTER VIEW public.goods_grp_active_multilang OWNER TO postgres;

--
-- TOC entry 5301 (class 0 OID 0)
-- Dependencies: 250
-- Name: VIEW goods_grp_active_multilang; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.goods_grp_active_multilang IS 'Активные группы товаров с поддержкой русского и английского языков и типом товара';


--
-- TOC entry 246 (class 1259 OID 16949)
-- Name: goods_grp_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.goods_grp_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.goods_grp_id_seq OWNER TO postgres;

--
-- TOC entry 5302 (class 0 OID 0)
-- Dependencies: 246
-- Name: goods_grp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.goods_grp_id_seq OWNED BY public.goods_grp.id;


--
-- TOC entry 248 (class 1259 OID 16959)
-- Name: goods_grp_loc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.goods_grp_loc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.goods_grp_loc_id_seq OWNER TO postgres;

--
-- TOC entry 5303 (class 0 OID 0)
-- Dependencies: 248
-- Name: goods_grp_loc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.goods_grp_loc_id_seq OWNED BY public.goods_grp_loc.id;


--
-- TOC entry 252 (class 1259 OID 16988)
-- Name: goods_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.goods_type (
    id integer NOT NULL,
    active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.goods_type OWNER TO postgres;

--
-- TOC entry 5304 (class 0 OID 0)
-- Dependencies: 252
-- Name: TABLE goods_type; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.goods_type IS 'Типы товаров';


--
-- TOC entry 254 (class 1259 OID 16998)
-- Name: goods_type_loc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.goods_type_loc (
    id integer NOT NULL,
    goods_type_id integer NOT NULL,
    locale character varying(2) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    CONSTRAINT goods_type_loc_locale_check CHECK (((locale)::text = ANY ((ARRAY['ru'::character varying, 'en'::character varying])::text[])))
);


ALTER TABLE public.goods_type_loc OWNER TO postgres;

--
-- TOC entry 5305 (class 0 OID 0)
-- Dependencies: 254
-- Name: TABLE goods_type_loc; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.goods_type_loc IS 'Локализация типов товаров';


--
-- TOC entry 255 (class 1259 OID 17019)
-- Name: goods_type_active_multilang; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.goods_type_active_multilang AS
 SELECT t.id,
    t.active,
    COALESCE(ru.name, en.name, ''::character varying) AS name_ru,
    COALESCE(ru.description, en.description, ''::text) AS description_ru,
    COALESCE(en.name, ru.name, ''::character varying) AS name_en,
    COALESCE(en.description, ru.description, ''::text) AS description_en
   FROM ((public.goods_type t
     LEFT JOIN public.goods_type_loc ru ON (((t.id = ru.goods_type_id) AND ((ru.locale)::text = 'ru'::text))))
     LEFT JOIN public.goods_type_loc en ON (((t.id = en.goods_type_id) AND ((en.locale)::text = 'en'::text))))
  WHERE (t.active = true)
  ORDER BY t.id;


ALTER VIEW public.goods_type_active_multilang OWNER TO postgres;

--
-- TOC entry 5306 (class 0 OID 0)
-- Dependencies: 255
-- Name: VIEW goods_type_active_multilang; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.goods_type_active_multilang IS 'Активные типы товаров с поддержкой русского и английского языков';


--
-- TOC entry 251 (class 1259 OID 16987)
-- Name: goods_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.goods_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.goods_type_id_seq OWNER TO postgres;

--
-- TOC entry 5307 (class 0 OID 0)
-- Dependencies: 251
-- Name: goods_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.goods_type_id_seq OWNED BY public.goods_type.id;


--
-- TOC entry 253 (class 1259 OID 16997)
-- Name: goods_type_loc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.goods_type_loc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.goods_type_loc_id_seq OWNER TO postgres;

--
-- TOC entry 5308 (class 0 OID 0)
-- Dependencies: 253
-- Name: goods_type_loc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.goods_type_loc_id_seq OWNED BY public.goods_type_loc.id;


--
-- TOC entry 223 (class 1259 OID 16464)
-- Name: localization; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.localization (
    loctype integer NOT NULL,
    colname character varying(20) NOT NULL,
    locale character(2) DEFAULT 'RU'::bpchar NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.localization OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 16474)
-- Name: logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.logs (
    date date,
    "time" time without time zone,
    "end" integer,
    func text,
    message text
);


ALTER TABLE public.logs OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16479)
-- Name: ltypes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ltypes (
    loctype integer NOT NULL,
    value_ru text NOT NULL,
    value_en text NOT NULL
);


ALTER TABLE public.ltypes OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 16713)
-- Name: photos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.photos (
    vendorcode character varying(10) CONSTRAINT photos_new_vendorcode_not_null NOT NULL,
    small text,
    big text
);


ALTER TABLE public.photos OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 16493)
-- Name: prices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.prices (
    nmid bigint NOT NULL,
    price numeric(10,2),
    discount numeric(5,2),
    promocode numeric(5,2),
    currentprice numeric(10,2),
    dayprice numeric(10,2),
    nightprice numeric(10,2),
    daydisc numeric(5,2),
    nightdisc numeric(5,2),
    active character(1)
);


ALTER TABLE public.prices OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 17045)
-- Name: product_data; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.product_data AS
 SELECT g.card_photo,
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
    COALESCE(gt.name_ru, ''::character varying) AS goods_type_name,
    g.goods_grp_id,
    COALESCE(gg.name_ru, ''::character varying) AS goods_grp_name
   FROM (((public.goods g
     LEFT JOIN public.cost_price cp ON ((((cp.vendorcode)::text = (g.vendorcode)::text) AND (cp.end_date IS NULL))))
     LEFT JOIN public.goods_grp_active_multilang gg ON ((g.goods_grp_id = gg.id)))
     LEFT JOIN public.goods_type_active_multilang gt ON ((gg.goods_type_id = gt.id)))
  ORDER BY g.vendorcode;


ALTER VIEW public.product_data OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 16497)
-- Name: user_api_keys; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_api_keys (
    user_id integer NOT NULL,
    key_type smallint NOT NULL,
    api_key text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.user_api_keys OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 16507)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    login character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_verified boolean DEFAULT false,
    verification_token character varying(255)
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 16517)
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- TOC entry 5309 (class 0 OID 0)
-- Dependencies: 229
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 4993 (class 2604 OID 16665)
-- Name: cost_price id_cost; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cost_price ALTER COLUMN id_cost SET DEFAULT nextval('public.cost_price_id_cost_seq'::regclass);


--
-- TOC entry 4998 (class 2604 OID 16810)
-- Name: fi_ohcat id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_ohcat ALTER COLUMN id SET DEFAULT nextval('public.fi_ohcat_id_seq'::regclass);


--
-- TOC entry 5000 (class 2604 OID 16820)
-- Name: fi_ohcat_loc id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_ohcat_loc ALTER COLUMN id SET DEFAULT nextval('public.fi_ohcat_loc_id_seq'::regclass);


--
-- TOC entry 5001 (class 2604 OID 16892)
-- Name: fi_ohgrp id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_ohgrp ALTER COLUMN id SET DEFAULT nextval('public.fi_ohgrp_id_seq'::regclass);


--
-- TOC entry 5003 (class 2604 OID 16902)
-- Name: fi_ohgrp_loc id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_ohgrp_loc ALTER COLUMN id SET DEFAULT nextval('public.fi_ohgrp_loc_id_seq'::regclass);


--
-- TOC entry 4996 (class 2604 OID 16796)
-- Name: gen_platforms id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gen_platforms ALTER COLUMN id SET DEFAULT nextval('public.gen_platforms_id_seq'::regclass);


--
-- TOC entry 5004 (class 2604 OID 16953)
-- Name: goods_grp id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_grp ALTER COLUMN id SET DEFAULT nextval('public.goods_grp_id_seq'::regclass);


--
-- TOC entry 5006 (class 2604 OID 16963)
-- Name: goods_grp_loc id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_grp_loc ALTER COLUMN id SET DEFAULT nextval('public.goods_grp_loc_id_seq'::regclass);


--
-- TOC entry 5007 (class 2604 OID 16991)
-- Name: goods_type id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_type ALTER COLUMN id SET DEFAULT nextval('public.goods_type_id_seq'::regclass);


--
-- TOC entry 5009 (class 2604 OID 17001)
-- Name: goods_type_loc id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_type_loc ALTER COLUMN id SET DEFAULT nextval('public.goods_type_loc_id_seq'::regclass);


--
-- TOC entry 4990 (class 2604 OID 16520)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 5021 (class 2606 OID 16522)
-- Name: api_key_types api_key_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_key_types
    ADD CONSTRAINT api_key_types_pkey PRIMARY KEY (key_type);


--
-- TOC entry 5047 (class 2606 OID 16674)
-- Name: cost_price cost_price_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cost_price
    ADD CONSTRAINT cost_price_pkey PRIMARY KEY (id_cost);


--
-- TOC entry 5049 (class 2606 OID 16676)
-- Name: cost_price cost_price_unique_period; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cost_price
    ADD CONSTRAINT cost_price_unique_period UNIQUE (vendorcode, beg_date);


--
-- TOC entry 5023 (class 2606 OID 16526)
-- Name: crm_headers crm_headers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crm_headers
    ADD CONSTRAINT crm_headers_pkey PRIMARY KEY (advertid, user_id);


--
-- TOC entry 5025 (class 2606 OID 16528)
-- Name: crm_status crm_status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crm_status
    ADD CONSTRAINT crm_status_pkey PRIMARY KEY (crmstatus);


--
-- TOC entry 5027 (class 2606 OID 16530)
-- Name: crm_type crm_type_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crm_type
    ADD CONSTRAINT crm_type_pkey PRIMARY KEY (crmtype);


--
-- TOC entry 5062 (class 2606 OID 16831)
-- Name: fi_ohcat_loc fi_ohcat_loc_ohcat_id_locale_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_ohcat_loc
    ADD CONSTRAINT fi_ohcat_loc_ohcat_id_locale_key UNIQUE (ohcat_id, locale);


--
-- TOC entry 5064 (class 2606 OID 16829)
-- Name: fi_ohcat_loc fi_ohcat_loc_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_ohcat_loc
    ADD CONSTRAINT fi_ohcat_loc_pkey PRIMARY KEY (id);


--
-- TOC entry 5059 (class 2606 OID 16815)
-- Name: fi_ohcat fi_ohcat_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_ohcat
    ADD CONSTRAINT fi_ohcat_pkey PRIMARY KEY (id);


--
-- TOC entry 5069 (class 2606 OID 16913)
-- Name: fi_ohgrp_loc fi_ohgrp_loc_ohgrp_id_locale_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_ohgrp_loc
    ADD CONSTRAINT fi_ohgrp_loc_ohgrp_id_locale_key UNIQUE (ohgrp_id, locale);


--
-- TOC entry 5071 (class 2606 OID 16911)
-- Name: fi_ohgrp_loc fi_ohgrp_loc_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_ohgrp_loc
    ADD CONSTRAINT fi_ohgrp_loc_pkey PRIMARY KEY (id);


--
-- TOC entry 5067 (class 2606 OID 16897)
-- Name: fi_ohgrp fi_ohgrp_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_ohgrp
    ADD CONSTRAINT fi_ohgrp_pkey PRIMARY KEY (id);


--
-- TOC entry 5089 (class 2606 OID 17066)
-- Name: fi_overheads fi_overheads_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_overheads
    ADD CONSTRAINT fi_overheads_pkey PRIMARY KEY (user_id, month, ohcat_id, platform);


--
-- TOC entry 5055 (class 2606 OID 16805)
-- Name: gen_platforms gen_platforms_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gen_platforms
    ADD CONSTRAINT gen_platforms_code_key UNIQUE (code);


--
-- TOC entry 5057 (class 2606 OID 16803)
-- Name: gen_platforms gen_platforms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gen_platforms
    ADD CONSTRAINT gen_platforms_pkey PRIMARY KEY (id);


--
-- TOC entry 5077 (class 2606 OID 16974)
-- Name: goods_grp_loc goods_grp_loc_goods_grp_id_locale_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_grp_loc
    ADD CONSTRAINT goods_grp_loc_goods_grp_id_locale_key UNIQUE (goods_grp_id, locale);


--
-- TOC entry 5079 (class 2606 OID 16972)
-- Name: goods_grp_loc goods_grp_loc_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_grp_loc
    ADD CONSTRAINT goods_grp_loc_pkey PRIMARY KEY (id);


--
-- TOC entry 5074 (class 2606 OID 16958)
-- Name: goods_grp goods_grp_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_grp
    ADD CONSTRAINT goods_grp_pkey PRIMARY KEY (id);


--
-- TOC entry 5041 (class 2606 OID 16660)
-- Name: goods goods_new_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods
    ADD CONSTRAINT goods_new_pkey PRIMARY KEY (vendorcode);


--
-- TOC entry 5084 (class 2606 OID 17012)
-- Name: goods_type_loc goods_type_loc_goods_type_id_locale_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_type_loc
    ADD CONSTRAINT goods_type_loc_goods_type_id_locale_key UNIQUE (goods_type_id, locale);


--
-- TOC entry 5086 (class 2606 OID 17010)
-- Name: goods_type_loc goods_type_loc_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_type_loc
    ADD CONSTRAINT goods_type_loc_pkey PRIMARY KEY (id);


--
-- TOC entry 5082 (class 2606 OID 16996)
-- Name: goods_type goods_type_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_type
    ADD CONSTRAINT goods_type_pkey PRIMARY KEY (id);


--
-- TOC entry 5029 (class 2606 OID 16947)
-- Name: localization localization_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.localization
    ADD CONSTRAINT localization_pkey PRIMARY KEY (loctype, colname, locale);


--
-- TOC entry 5031 (class 2606 OID 16542)
-- Name: ltypes ltypes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ltypes
    ADD CONSTRAINT ltypes_pkey PRIMARY KEY (loctype);


--
-- TOC entry 5053 (class 2606 OID 16720)
-- Name: photos photos_new_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.photos
    ADD CONSTRAINT photos_new_pkey PRIMARY KEY (vendorcode);


--
-- TOC entry 5033 (class 2606 OID 16546)
-- Name: prices prices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prices
    ADD CONSTRAINT prices_pkey PRIMARY KEY (nmid);


--
-- TOC entry 5035 (class 2606 OID 16548)
-- Name: user_api_keys user_api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_api_keys
    ADD CONSTRAINT user_api_keys_pkey PRIMARY KEY (user_id, key_type);


--
-- TOC entry 5037 (class 2606 OID 16550)
-- Name: users users_login_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_login_key UNIQUE (login);


--
-- TOC entry 5039 (class 2606 OID 16552)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 5050 (class 1259 OID 16682)
-- Name: idx_cost_price_dates; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cost_price_dates ON public.cost_price USING btree (vendorcode, beg_date, end_date);


--
-- TOC entry 5051 (class 1259 OID 16683)
-- Name: idx_cost_price_vendorcode; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cost_price_vendorcode ON public.cost_price USING btree (vendorcode);


--
-- TOC entry 5042 (class 1259 OID 16687)
-- Name: idx_goods_deleted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_goods_deleted ON public.goods USING btree (deleted) WHERE (deleted = true);


--
-- TOC entry 5043 (class 1259 OID 17044)
-- Name: idx_goods_grp_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_goods_grp_id ON public.goods USING btree (goods_grp_id);


--
-- TOC entry 5080 (class 1259 OID 16980)
-- Name: idx_goods_grp_loc_grp; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_goods_grp_loc_grp ON public.goods_grp_loc USING btree (goods_grp_id);


--
-- TOC entry 5075 (class 1259 OID 17030)
-- Name: idx_goods_grp_type_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_goods_grp_type_id ON public.goods_grp USING btree (goods_type_id);


--
-- TOC entry 5044 (class 1259 OID 16686)
-- Name: idx_goods_nmid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_goods_nmid ON public.goods USING btree (nmid);


--
-- TOC entry 5087 (class 1259 OID 17018)
-- Name: idx_goods_type_loc_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_goods_type_loc_type ON public.goods_type_loc USING btree (goods_type_id);


--
-- TOC entry 5045 (class 1259 OID 16688)
-- Name: idx_goods_vendor_deleted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_goods_vendor_deleted ON public.goods USING btree (vendorcode, deleted);


--
-- TOC entry 5065 (class 1259 OID 16837)
-- Name: idx_ohcat_loc_ohcat; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ohcat_loc_ohcat ON public.fi_ohcat_loc USING btree (ohcat_id);


--
-- TOC entry 5060 (class 1259 OID 16931)
-- Name: idx_ohcat_oh_grp_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ohcat_oh_grp_id ON public.fi_ohcat USING btree (oh_grp_id);


--
-- TOC entry 5072 (class 1259 OID 16919)
-- Name: idx_ohgrp_loc_ohgrp; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ohgrp_loc_ohgrp ON public.fi_ohgrp_loc USING btree (ohgrp_id);


--
-- TOC entry 5090 (class 1259 OID 17078)
-- Name: idx_overheads_month; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_overheads_month ON public.fi_overheads USING btree (month);


--
-- TOC entry 5091 (class 1259 OID 17077)
-- Name: idx_overheads_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_overheads_user ON public.fi_overheads USING btree (user_id);


--
-- TOC entry 5092 (class 1259 OID 17079)
-- Name: idx_overheads_user_month; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_overheads_user_month ON public.fi_overheads USING btree (user_id, month);


--
-- TOC entry 5110 (class 2620 OID 16555)
-- Name: crm_headers campaign_notify_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER campaign_notify_trigger AFTER UPDATE ON public.crm_headers FOR EACH ROW WHEN (((new.active IS DISTINCT FROM old.active) OR (new.pause_time IS DISTINCT FROM old.pause_time) OR (new.restart_time IS DISTINCT FROM old.restart_time))) EXECUTE FUNCTION public.notify_campaign_update();


--
-- TOC entry 5111 (class 2620 OID 16556)
-- Name: crm_headers campaign_update_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER campaign_update_trigger BEFORE UPDATE ON public.crm_headers FOR EACH ROW EXECUTE FUNCTION public.update_campaign_timestamp();


--
-- TOC entry 5113 (class 2620 OID 17081)
-- Name: fi_overheads trigger_overheads_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_overheads_updated_at BEFORE UPDATE ON public.fi_overheads FOR EACH ROW EXECUTE FUNCTION public.update_overheads_updated_at();


--
-- TOC entry 5112 (class 2620 OID 16685)
-- Name: cost_price update_cost_price_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_cost_price_updated_at BEFORE UPDATE ON public.cost_price FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- TOC entry 5100 (class 2606 OID 16677)
-- Name: cost_price cost_price_vendorcode_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cost_price
    ADD CONSTRAINT cost_price_vendorcode_fk FOREIGN KEY (vendorcode) REFERENCES public.goods(vendorcode) ON DELETE CASCADE;


--
-- TOC entry 5102 (class 2606 OID 16926)
-- Name: fi_ohcat fi_ohcat_grp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_ohcat
    ADD CONSTRAINT fi_ohcat_grp_id_fkey FOREIGN KEY (oh_grp_id) REFERENCES public.fi_ohgrp(id) ON DELETE SET NULL;


--
-- TOC entry 5103 (class 2606 OID 16832)
-- Name: fi_ohcat_loc fi_ohcat_loc_ohcat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_ohcat_loc
    ADD CONSTRAINT fi_ohcat_loc_ohcat_id_fkey FOREIGN KEY (ohcat_id) REFERENCES public.fi_ohcat(id) ON DELETE CASCADE;


--
-- TOC entry 5104 (class 2606 OID 16914)
-- Name: fi_ohgrp_loc fi_ohgrp_loc_ohgrp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_ohgrp_loc
    ADD CONSTRAINT fi_ohgrp_loc_ohgrp_id_fkey FOREIGN KEY (ohgrp_id) REFERENCES public.fi_ohgrp(id) ON DELETE CASCADE;


--
-- TOC entry 5108 (class 2606 OID 17072)
-- Name: fi_overheads fi_overheads_ohcat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_overheads
    ADD CONSTRAINT fi_overheads_ohcat_id_fkey FOREIGN KEY (ohcat_id) REFERENCES public.fi_ohcat(id) ON DELETE RESTRICT;


--
-- TOC entry 5109 (class 2606 OID 17067)
-- Name: fi_overheads fi_overheads_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fi_overheads
    ADD CONSTRAINT fi_overheads_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5093 (class 2606 OID 16564)
-- Name: crm_headers fk_crm_status; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crm_headers
    ADD CONSTRAINT fk_crm_status FOREIGN KEY (crmstatus) REFERENCES public.crm_status(crmstatus) NOT VALID;


--
-- TOC entry 5094 (class 2606 OID 16569)
-- Name: crm_headers fk_crm_types; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crm_headers
    ADD CONSTRAINT fk_crm_types FOREIGN KEY (crmtype) REFERENCES public.crm_type(crmtype) NOT VALID;


--
-- TOC entry 5097 (class 2606 OID 16574)
-- Name: user_api_keys fk_keytype; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_api_keys
    ADD CONSTRAINT fk_keytype FOREIGN KEY (key_type) REFERENCES public.api_key_types(key_type);


--
-- TOC entry 5096 (class 2606 OID 16579)
-- Name: localization fk_localization_loctype; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.localization
    ADD CONSTRAINT fk_localization_loctype FOREIGN KEY (loctype) REFERENCES public.ltypes(loctype) ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 5098 (class 2606 OID 16599)
-- Name: user_api_keys fk_userid; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_api_keys
    ADD CONSTRAINT fk_userid FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 5095 (class 2606 OID 16604)
-- Name: crm_headers fk_users; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crm_headers
    ADD CONSTRAINT fk_users FOREIGN KEY (user_id) REFERENCES public.users(id) NOT VALID;


--
-- TOC entry 5099 (class 2606 OID 17039)
-- Name: goods goods_goods_grp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods
    ADD CONSTRAINT goods_goods_grp_id_fkey FOREIGN KEY (goods_grp_id) REFERENCES public.goods_grp(id) ON DELETE SET NULL;


--
-- TOC entry 5105 (class 2606 OID 17025)
-- Name: goods_grp goods_grp_goods_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_grp
    ADD CONSTRAINT goods_grp_goods_type_id_fkey FOREIGN KEY (goods_type_id) REFERENCES public.goods_type(id) ON DELETE SET NULL;


--
-- TOC entry 5106 (class 2606 OID 16975)
-- Name: goods_grp_loc goods_grp_loc_goods_grp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_grp_loc
    ADD CONSTRAINT goods_grp_loc_goods_grp_id_fkey FOREIGN KEY (goods_grp_id) REFERENCES public.goods_grp(id) ON DELETE CASCADE;


--
-- TOC entry 5107 (class 2606 OID 17013)
-- Name: goods_type_loc goods_type_loc_goods_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goods_type_loc
    ADD CONSTRAINT goods_type_loc_goods_type_id_fkey FOREIGN KEY (goods_type_id) REFERENCES public.goods_type(id) ON DELETE CASCADE;


--
-- TOC entry 5101 (class 2606 OID 16721)
-- Name: photos photos_vendorcode_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.photos
    ADD CONSTRAINT photos_vendorcode_fk FOREIGN KEY (vendorcode) REFERENCES public.goods(vendorcode) ON DELETE CASCADE;


-- Completed on 2026-06-11 11:01:48

--
-- PostgreSQL database dump complete
--

\unrestrict QrwaFjl3M5Nz6NdbCg2evtgwlldvNEnJjB7HZ3OCFkaUa6ELK25Upgq1iYOlbjy

