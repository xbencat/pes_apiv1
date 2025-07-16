--
-- PostgreSQL database dump
--

-- Dumped from database version 14.6
-- Dumped by pg_dump version 14.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: f_random_sample(anyelement, text, integer, real); Type: FUNCTION; Schema: public; Owner: cmdb_user1
--

CREATE FUNCTION public.f_random_sample(_tbl_type anyelement, _id text DEFAULT 'id'::text, _limit integer DEFAULT 1000, _gaps real DEFAULT 1.03) RETURNS SETOF anyelement
    LANGUAGE plpgsql
    AS $_$
DECLARE
   -- safe syntax with schema & quotes where needed
   _tbl text := pg_typeof(_tbl_type)::text;
   _estimate int := (SELECT (reltuples / relpages
                          * (pg_relation_size(oid) / 8192))::bigint
                     FROM   pg_class  -- get current estimate from system
                     WHERE  oid = _tbl::regclass);
BEGIN
   RETURN QUERY EXECUTE format(
   $$
   WITH RECURSIVE random_pick AS (
      SELECT *
      FROM  (
         SELECT 1 + trunc(random() * $1)::int
         FROM   generate_series(1, $2) g
         LIMIT  $2                 -- hint for query planner
         ) r(%2$I)
      JOIN   %1$s USING (%2$I)     -- eliminate misses

      UNION                        -- eliminate dupes
      SELECT *
      FROM  (
         SELECT 1 + trunc(random() * $1)::int
         FROM   random_pick        -- just to make it recursive
         LIMIT  $3                 -- hint for query planner
         ) r(%2$I)
      JOIN   %1$s USING (%2$I)     -- eliminate misses
   )
   TABLE  random_pick
   LIMIT  $3;
   $$
 , _tbl, _id
   )
   USING _estimate              -- $1
       , (_limit * _gaps)::int  -- $2 ("surplus")
       , _limit                 -- $3
   ;
END
$_$;


ALTER FUNCTION public.f_random_sample(_tbl_type anyelement, _id text, _limit integer, _gaps real) OWNER TO cmdb_user1;

--
-- Name: fmt_name(text, text, boolean, text); Type: FUNCTION; Schema: public; Owner: cmdb_user1
--

CREATE FUNCTION public.fmt_name(last_name text, first_name text, swap_order boolean DEFAULT false, fallback text DEFAULT '<N/A>'::text) RETURNS text
    LANGUAGE plpgsql
    AS $$
    DECLARE
        _out TEXT := '';
        _first TEXT := COALESCE(last_name, '');
        _second TEXT := COALESCE(first_name, '');
    BEGIN
        IF length(_first) < 1 AND length(_second) < 1 THEN
            RETURN fallback;
        END IF;
    
        IF swap_order THEN
            _first := COALESCE(first_name, '');
            _second := COALESCE(last_name, '');
        END IF;

        IF length(_first) > 0 THEN
            _out := _out || _first;
            IF length(_second) > 0 THEN
                _out := _out || ' ';
            END IF;
        END IF;
    
        IF length(_second) > 0 THEN
            _out := _out || _second;
        END IF;
    
        RETURN _out;
    END
$$;


ALTER FUNCTION public.fmt_name(last_name text, first_name text, swap_order boolean, fallback text) OWNER TO cmdb_user1;

--
-- Name: get_attribute_value(text, text, text, text[], jsonb); Type: FUNCTION; Schema: public; Owner: cmdb_user1
--

CREATE FUNCTION public.get_attribute_value(reference_type text, reference_table text, reference_table_pk text, reference_table_columns text[], attr_value jsonb) RETURNS jsonb
    LANGUAGE plpgsql STRICT
    AS $_$
    DECLARE
        _out jsonb;
    BEGIN
        IF reference_type = 'table' THEN
            EXECUTE 'SELECT jsonb_build_object(''value'', ' || array_to_string(reference_table_columns, '|| '' '' ||') || ', ''attribute_id'', $1->>''value'') ' ||
                    'FROM ' || reference_table || ' ' ||
                    'WHERE "' || reference_table_pk || '"::text = $1->>''value''' INTO _out USING attr_value;
        ELSEIF reference_type = 'enum' THEN
            SELECT cav.attribute_value INTO _out
            FROM public.loan_attribute_value AS cav
            WHERE cav.loan_attribute_value_id::text = attr_value->>'value';
        END IF;
        RETURN _out;
    END
$_$;


ALTER FUNCTION public.get_attribute_value(reference_type text, reference_table text, reference_table_pk text, reference_table_columns text[], attr_value jsonb) OWNER TO cmdb_user1;

--
-- Name: get_person_attribute_value(text, text, text, text[], jsonb); Type: FUNCTION; Schema: public; Owner: cmdb_user1
--

CREATE FUNCTION public.get_person_attribute_value(reference_type text, reference_table text, reference_table_pk text, reference_table_columns text[], attr_value jsonb) RETURNS jsonb
    LANGUAGE plpgsql STRICT
    AS $_$
    DECLARE
        _out jsonb;
    BEGIN
        IF reference_type = 'table' THEN
            EXECUTE 'SELECT jsonb_build_object(''value'', ' || array_to_string(reference_table_columns, '|| '' '' ||') || ', ''attribute_id'', $1->>''value'') ' ||
                    'FROM ' || reference_table || ' ' ||
                    'WHERE "' || reference_table_pk || '"::text = $1->>''value''' INTO _out USING attr_value;
        ELSEIF reference_type = 'enum' THEN
            SELECT pav.attribute_value INTO _out
            FROM public.person_attribute_value AS pav
            WHERE pav.person_attribute_value_id::text = attr_value->>'value';
        END IF;
        RETURN _out;
    END
$_$;


ALTER FUNCTION public.get_person_attribute_value(reference_type text, reference_table text, reference_table_pk text, reference_table_columns text[], attr_value jsonb) OWNER TO cmdb_user1;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: attachment_category; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.attachment_category (
    attachment_category_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    attachment_category_name text NOT NULL,
    attachment_category_descr text NOT NULL,
    is_deleted boolean DEFAULT false
);


ALTER TABLE public.attachment_category OWNER TO cmdb_user1;

--
-- Name: loan_number; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.loan_number
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.loan_number OWNER TO cmdb_user1;

--
-- Name: loan; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.loan (
    loan_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    loan_number bigint DEFAULT nextval('public.loan_number'::regclass) NOT NULL,
    loan_title character varying(50),
    loan_description text,
    loan_type_id smallint,
    loan_status_id smallint,
    owner_person_id character varying(36) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    modified_at timestamp without time zone DEFAULT now(),
    modified_by character varying(36),
    is_locked boolean DEFAULT false,
    notes text
);


ALTER TABLE public.loan OWNER TO cmdb_user1;

--
-- Name: COLUMN loan.owner_person_id; Type: COMMENT; Schema: public; Owner: cmdb_user1
--

COMMENT ON COLUMN public.loan.owner_person_id IS 'Debtor';


--
-- Name: COLUMN loan.notes; Type: COMMENT; Schema: public; Owner: cmdb_user1
--

COMMENT ON COLUMN public.loan.notes IS 'Notes - Scratchpad';


--
-- Name: loan_attribute; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.loan_attribute (
    loan_id character varying(36) NOT NULL,
    loan_attribute_type_id character varying(36) NOT NULL,
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone,
    created_by character varying(36) NOT NULL,
    deleted_by character varying(36),
    attribute_value jsonb DEFAULT '{"value": 0}'::jsonb NOT NULL
);


ALTER TABLE public.loan_attribute OWNER TO cmdb_user1;

--
-- Name: loan_attribute_type; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.loan_attribute_type (
    loan_attribute_type_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    loan_attribute_type_label text NOT NULL,
    loan_attribute_type_datatype text NOT NULL,
    is_reference boolean DEFAULT false NOT NULL,
    reference_type text,
    reference_table text,
    reference_table_pk text,
    reference_table_columns text[],
    loan_attribute_design jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    deleted_by character varying(36),
    deleted_at timestamp without time zone
);


ALTER TABLE public.loan_attribute_type OWNER TO cmdb_user1;

--
-- Name: loan_type_loan_attribute_type; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.loan_type_loan_attribute_type (
    loan_type_id smallint NOT NULL,
    loan_attribute_type_id character varying(36) NOT NULL,
    is_readonly boolean DEFAULT false NOT NULL,
    is_audited boolean DEFAULT true NOT NULL,
    is_named_attribute boolean DEFAULT false NOT NULL,
    relative_order smallint,
    is_optional boolean DEFAULT false NOT NULL
);


ALTER TABLE public.loan_type_loan_attribute_type OWNER TO cmdb_user1;

--
-- Name: loan_attribute_list_all; Type: VIEW; Schema: public; Owner: cmdb_user1
--

CREATE VIEW public.loan_attribute_list_all AS
 SELECT gc.loan_id,
    ca.valid_from,
    ca.valid_to,
    ca.created_by,
    cat.loan_attribute_type_id AS attribute_type_id,
    cat.loan_attribute_type_label AS attribute_label,
    cat.loan_attribute_type_datatype AS attribute_datatype,
    cat.loan_attribute_design AS attribute_design,
    ctcat.is_readonly,
    ctcat.is_audited,
    ctcat.is_named_attribute,
    ctcat.relative_order,
        CASE
            WHEN (cat.is_reference IS TRUE) THEN public.get_attribute_value(cat.reference_type, cat.reference_table, COALESCE(cat.reference_table_pk, ''::text), COALESCE(cat.reference_table_columns, '{}'::text[]), ca.attribute_value)
            ELSE ca.attribute_value
        END AS attribute_value,
    cat.is_reference,
    cat.reference_type
   FROM (((public.loan_attribute ca
     JOIN public.loan_attribute_type cat ON (((cat.loan_attribute_type_id)::text = (ca.loan_attribute_type_id)::text)))
     JOIN public.loan_type_loan_attribute_type ctcat ON (((ctcat.loan_attribute_type_id)::text = (cat.loan_attribute_type_id)::text)))
     JOIN public.loan gc ON ((((gc.loan_id)::text = (ca.loan_id)::text) AND (gc.loan_type_id = ctcat.loan_type_id))));


ALTER TABLE public.loan_attribute_list_all OWNER TO cmdb_user1;

--
-- Name: loan_attribute_value; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.loan_attribute_value (
    loan_attribute_value_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    loan_attribute_type_id character varying(36) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    deleted_at timestamp without time zone,
    deleted_by character varying(36),
    attribute_value jsonb DEFAULT '{"value": 0}'::jsonb NOT NULL
);


ALTER TABLE public.loan_attribute_value OWNER TO cmdb_user1;

--
-- Name: loan_charge; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.loan_charge (
    loan_charge_id bigint NOT NULL,
    loan_id character varying(36) NOT NULL,
    charge_id integer,
    due_date timestamp without time zone NOT NULL,
    amount double precision NOT NULL,
    currency character varying(36),
    variable_symbol character varying(10),
    specific_symbol character varying(10),
    constant_symbol character varying(10),
    reminder_at timestamp without time zone,
    is_valid boolean DEFAULT true NOT NULL,
    config jsonb,
    payment_type text
);


ALTER TABLE public.loan_charge OWNER TO cmdb_user1;

--
-- Name: loan_charge_loan_charge_id_seq; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.loan_charge_loan_charge_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.loan_charge_loan_charge_id_seq OWNER TO cmdb_user1;

--
-- Name: loan_charge_loan_charge_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cmdb_user1
--

ALTER SEQUENCE public.loan_charge_loan_charge_id_seq OWNED BY public.loan_charge.loan_charge_id;


--
-- Name: loan_event; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.loan_event (
    loan_event_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    loan_id character varying(36) NOT NULL,
    parent_loan_event character varying(36),
    person_id character varying(36),
    created_at timestamp without time zone DEFAULT now(),
    modified_at timestamp without time zone,
    is_deleted boolean DEFAULT false,
    loan_event_type_id smallint NOT NULL,
    subject character varying(100),
    message text,
    attachment_path character varying(512),
    attachment_title character varying(512),
    old_event_value_int smallint,
    old_event_value_json jsonb,
    new_event_value_int smallint,
    new_event_value_json jsonb,
    tags text[] DEFAULT '{}'::text[]
);


ALTER TABLE public.loan_event OWNER TO cmdb_user1;

--
-- Name: loan_event_type; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.loan_event_type (
    loan_event_type_id smallint NOT NULL,
    loan_event_type_name text NOT NULL,
    loan_event_type_message text NOT NULL,
    has_attachment boolean DEFAULT false NOT NULL,
    is_attribute_change boolean DEFAULT false NOT NULL,
    loan_event_design jsonb DEFAULT '{}'::jsonb NOT NULL
);


ALTER TABLE public.loan_event_type OWNER TO cmdb_user1;

--
-- Name: loan_event_type_loan_event_type_id_seq; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.loan_event_type_loan_event_type_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.loan_event_type_loan_event_type_id_seq OWNER TO cmdb_user1;

--
-- Name: loan_event_type_loan_event_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cmdb_user1
--

ALTER SEQUENCE public.loan_event_type_loan_event_type_id_seq OWNED BY public.loan_event_type.loan_event_type_id;


--
-- Name: loan_file_list; Type: VIEW; Schema: public; Owner: cmdb_user1
--

CREATE VIEW public.loan_file_list AS
 SELECT ce.loan_id,
    ce.loan_event_id AS event_id,
    ce.person_id AS created_by,
    COALESCE(ce.modified_at, ce.created_at) AS event_time,
    ce.attachment_path AS file_path,
    ce.attachment_title AS file_name,
    jsonb_build_object('attachment_category_id', ac.attachment_category_id, 'attachment_category_name', ac.attachment_category_name, 'attachment_category_descr', ac.attachment_category_descr, 'file_size', (ce.new_event_value_json ->> 'file_size'::text), 'registry_document_number', (ce.new_event_value_json ->> 'registry_document_number'::text), 'registry_record_id', (ce.new_event_value_json ->> 'registry_record_id'::text)) AS config,
    COALESCE(((ce.new_event_value_json ->> 'document_deleted'::text))::boolean, false) AS is_deleted,
    (ce.new_event_value_json ->> 'document_deleted_at'::text) AS deleted_at,
    (ce.new_event_value_json ->> 'document_deleted_by'::text) AS deleted_by
   FROM ((public.loan_event ce
     JOIN public.loan_event_type cet ON ((cet.loan_event_type_id = ce.loan_event_type_id)))
     LEFT JOIN public.attachment_category ac ON (((ac.attachment_category_id)::text = (ce.new_event_value_json ->> 'attachment_category_id'::text))))
  WHERE ((NOT ce.is_deleted) AND (ce.loan_event_type_id = 4));


ALTER TABLE public.loan_file_list OWNER TO cmdb_user1;

--
-- Name: incomming_payment_installment; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.incomming_payment_installment (
    transaction_id character varying(512) NOT NULL,
    installment_id bigint NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(36) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    transaction_amount_drawn double precision NOT NULL
);


ALTER TABLE public.incomming_payment_installment OWNER TO cmdb_user1;

--
-- Name: installment; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.installment (
    installment_id bigint NOT NULL,
    installment_no smallint,
    loan_id character varying(36) NOT NULL,
    due_date timestamp without time zone NOT NULL,
    amount double precision NOT NULL,
    currency character varying(36),
    variable_symbol character varying(50) NOT NULL,
    reminder_at timestamp without time zone,
    is_valid boolean DEFAULT true NOT NULL,
    config jsonb
);


ALTER TABLE public.installment OWNER TO cmdb_user1;

--
-- Name: loan_overdue_installment; Type: VIEW; Schema: public; Owner: cmdb_user1
--

CREATE VIEW public.loan_overdue_installment AS
 WITH overdue_installment AS (
         SELECT i.loan_id,
            sum(i.amount) AS overdue_amount
           FROM (public.installment i
             LEFT JOIN public.incomming_payment_installment ipi ON ((ipi.installment_id = i.installment_id)))
          WHERE ((ipi.transaction_id IS NULL) AND (i.due_date < (now())::date) AND i.is_valid)
          GROUP BY i.loan_id
        )
 SELECT gc.loan_id,
    COALESCE(oi.overdue_amount, (0)::double precision) AS overdue_amount
   FROM (public.loan gc
     LEFT JOIN overdue_installment oi ON (((oi.loan_id)::text = (gc.loan_id)::text)));


ALTER TABLE public.loan_overdue_installment OWNER TO cmdb_user1;

--
-- Name: loan_principal_amount; Type: VIEW; Schema: public; Owner: cmdb_user1
--

CREATE VIEW public.loan_principal_amount AS
 WITH principal_installment AS (
         SELECT i.loan_id,
            sum(i.amount) AS installment_amount
           FROM public.installment i
          WHERE i.is_valid
          GROUP BY i.loan_id
        ), principal_charge AS (
         SELECT cc.loan_id,
            sum(cc.amount) AS charge_amount
           FROM public.loan_charge cc
          WHERE (cc.is_valid AND (NOT COALESCE(((cc.config -> 'is_initial'::text))::boolean, false)) AND (NOT COALESCE(((cc.config -> 'is_returned_payment'::text))::boolean, false)))
          GROUP BY cc.loan_id
        ), mrg AS (
         SELECT gc.loan_id,
            COALESCE(pin.installment_amount, (0)::double precision) AS installment_amount,
            COALESCE(pcg.charge_amount, (0)::double precision) AS charge_amount,
            (pin.installment_amount IS NOT NULL) AS is_installment_calendar
           FROM ((public.loan gc
             LEFT JOIN principal_installment pin ON (((pin.loan_id)::text = (gc.loan_id)::text)))
             LEFT JOIN principal_charge pcg ON (((pcg.loan_id)::text = (gc.loan_id)::text)))
        )
 SELECT mrg.loan_id,
    mrg.installment_amount,
    mrg.charge_amount,
    (mrg.installment_amount + mrg.charge_amount) AS principal_amount,
    mrg.is_installment_calendar
   FROM mrg;


ALTER TABLE public.loan_principal_amount OWNER TO cmdb_user1;

--
-- Name: debt_writeoff; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.debt_writeoff (
    writeoff_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    loan_id character varying(36) NOT NULL,
    writeoff_amount double precision NOT NULL,
    writeoff_type_id character varying(36) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(36) NOT NULL,
    is_valid boolean DEFAULT true NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL
);


ALTER TABLE public.debt_writeoff OWNER TO cmdb_user1;

--
-- Name: incomming_payment; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.incomming_payment (
    transaction_id character varying(512) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    account_iban character varying(24) NOT NULL,
    counteraccount_iban character varying(24) NOT NULL,
    bic_swift character varying(10),
    amount double precision NOT NULL,
    currency character varying(36),
    due_date timestamp without time zone NOT NULL,
    sent_at timestamp without time zone,
    variable_symbol character varying(50),
    specific_symbol character varying(50),
    constant_symbol character varying(10),
    payment_purpose character varying(256),
    payer_name character varying(512),
    payer_address character varying(512),
    transaction_status_id smallint NOT NULL
);


ALTER TABLE public.incomming_payment OWNER TO cmdb_user1;

--
-- Name: loan_principal_balance; Type: VIEW; Schema: public; Owner: cmdb_user1
--

CREATE VIEW public.loan_principal_balance AS
 WITH income AS (
         SELECT i.loan_id,
            sum(ip.amount) AS recollected_amount
           FROM ((public.incomming_payment ip
             JOIN public.incomming_payment_installment ipi ON ((((ipi.transaction_id)::text = (ip.transaction_id)::text) AND (NOT ipi.is_deleted))))
             JOIN public.installment i ON ((i.installment_id = ipi.installment_id)))
          GROUP BY i.loan_id
        ), writeoffs AS (
         SELECT dw.loan_id,
            sum(dw.writeoff_amount) AS writeoff_amount
           FROM public.debt_writeoff dw
          WHERE dw.is_valid
          GROUP BY dw.loan_id
        ), returned_payments AS (
         SELECT cc.loan_id,
            sum(cc.amount) AS returned_amount
           FROM public.loan_charge cc
          WHERE (cc.is_valid AND COALESCE(((cc.config -> 'is_returned_payment'::text))::boolean, false))
          GROUP BY cc.loan_id
        ), mrg AS (
         SELECT cpa.loan_id,
            COALESCE(i.recollected_amount, (0)::double precision) AS recollected_amount,
            COALESCE(r.returned_amount, (0)::double precision) AS expense_amount,
            COALESCE(w.writeoff_amount, (0)::double precision) AS writeoff_amount,
            COALESCE(o.overdue_amount, (0)::double precision) AS overdue_amount,
            cpa.principal_amount
           FROM ((((public.loan_principal_amount cpa
             LEFT JOIN income i ON (((i.loan_id)::text = (cpa.loan_id)::text)))
             LEFT JOIN writeoffs w ON (((w.loan_id)::text = (cpa.loan_id)::text)))
             LEFT JOIN returned_payments r ON (((r.loan_id)::text = (cpa.loan_id)::text)))
             LEFT JOIN public.loan_overdue_installment o ON (((o.loan_id)::text = (cpa.loan_id)::text)))
        )
 SELECT mrg.loan_id,
    mrg.recollected_amount,
    mrg.expense_amount,
    mrg.writeoff_amount,
    (((mrg.principal_amount - mrg.writeoff_amount) - mrg.recollected_amount) - mrg.expense_amount) AS principal_balance,
    mrg.overdue_amount
   FROM mrg;


ALTER TABLE public.loan_principal_balance OWNER TO cmdb_user1;

--
-- Name: loan_status; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.loan_status (
    loan_status_id smallint NOT NULL,
    loan_status_label text NOT NULL,
    loan_status_descr text NOT NULL
);


ALTER TABLE public.loan_status OWNER TO cmdb_user1;

--
-- Name: loan_type; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.loan_type (
    loan_type_id smallint NOT NULL,
    loan_type_label text NOT NULL,
    loan_type_descr text NOT NULL,
    loan_type_abbr text,
    config jsonb DEFAULT '{"class": "badge badge-light-dark"}'::jsonb
);


ALTER TABLE public.loan_type OWNER TO cmdb_user1;

--
-- Name: natural_person; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.natural_person (
    person_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    personal_identification_number character varying(10) NOT NULL,
    first_name character varying(100),
    last_name character varying(100),
    title_before character varying(15),
    date_of_birth date NOT NULL,
    nationality text NOT NULL,
    address text NOT NULL,
    correspondence_address text,
    email text,
    phone_number text,
    created_at timestamp without time zone DEFAULT now(),
    last_modified timestamp without time zone DEFAULT now(),
    preference json,
    is_service_account boolean DEFAULT false NOT NULL,
    title_after character varying(15)
);


ALTER TABLE public.natural_person OWNER TO cmdb_user1;

--
-- Name: loan_list; Type: VIEW; Schema: public; Owner: cmdb_user1
--

CREATE VIEW public.loan_list AS
 WITH loan_attributes_mtx AS (
         SELECT cala.loan_id,
            ((cala.attribute_value ->> 'value'::text))::double precision AS loan_amount,
            NULL::text AS currency,
            NULL::text AS due_date,
            NULL::text AS referent,
            NULL::text AS guarantor
           FROM public.loan_attribute_list_all cala
          WHERE ((cala.valid_to IS NULL) AND ((cala.attribute_type_id)::text = '1dce07e0-fb42-4f83-ad7e-7217a66e573b'::text))
        UNION
         SELECT cala.loan_id,
            NULL::double precision AS loan_amount,
            (cala.attribute_value ->> 'value'::text) AS currency,
            NULL::text AS due_date,
            NULL::text AS referent,
            NULL::text AS guarantor
           FROM public.loan_attribute_list_all cala
          WHERE ((cala.valid_to IS NULL) AND ((cala.attribute_type_id)::text = '65d54fa2-0370-46aa-8288-73566f44e665'::text))
        UNION
         SELECT cala.loan_id,
            NULL::double precision AS loan_amount,
            NULL::text AS currency,
            (cala.attribute_value ->> 'value'::text) AS due_date,
            NULL::text AS referent,
            NULL::text AS guarantor
           FROM public.loan_attribute_list_all cala
          WHERE ((cala.valid_to IS NULL) AND ((cala.attribute_type_id)::text = '5eb4d34d-ac76-4ae1-b51a-66cc90e176a2'::text))
        UNION
         SELECT cala.loan_id,
            NULL::double precision AS loan_amount,
            NULL::text AS currency,
            NULL::text AS due_date,
            (cala.attribute_value ->> 'attribute_id'::text) AS referent,
            NULL::text AS guarantor
           FROM public.loan_attribute_list_all cala
          WHERE ((cala.valid_to IS NULL) AND ((cala.attribute_type_id)::text = 'b33702f4-635d-4ba9-b5ba-14fe448001c1'::text))
        UNION
         SELECT cala.loan_id,
            NULL::double precision AS loan_amount,
            NULL::text AS currency,
            NULL::text AS due_date,
            NULL::text AS referent,
            (cala.attribute_value ->> 'attribute_id'::text) AS guarantor
           FROM public.loan_attribute_list_all cala
          WHERE ((cala.valid_to IS NULL) AND ((cala.attribute_type_id)::text = '01675211-6e9b-442f-8886-1fffc5d62934'::text))
        ), loan_attributes AS (
         SELECT loan_attributes_mtx.loan_id,
            (array_remove(array_agg(loan_attributes_mtx.loan_amount), NULL::double precision))[1] AS loan_amount,
            (array_remove(array_agg(loan_attributes_mtx.currency), NULL::text))[1] AS currency,
            (array_remove(array_agg(loan_attributes_mtx.due_date), NULL::text))[1] AS due_date,
            (array_remove(array_agg(loan_attributes_mtx.referent), NULL::text))[1] AS referent,
            (array_remove(array_agg(loan_attributes_mtx.guarantor), NULL::text))[1] AS guarantor
           FROM loan_attributes_mtx
          GROUP BY loan_attributes_mtx.loan_id
        )
 SELECT gc.loan_id,
    gc.loan_number,
    gc.loan_title,
    gc.loan_description,
    gc.loan_type_id,
    ct.loan_type_label,
    ct.loan_type_descr,
    gc.loan_status_id,
    cs.loan_status_label,
    cs.loan_status_descr,
    gc.owner_person_id,
    owner_np.first_name AS owner_first_name,
    owner_np.last_name AS owner_last_name,
    cas.referent AS assessor_person_id,
    assessor_np.first_name AS assessor_first_name,
    assessor_np.last_name AS assessor_last_name,
    cas.guarantor AS guarantor_person_id,
    guarantor_np.first_name AS guarantor_first_name,
    guarantor_np.last_name AS guarantor_last_name,
    (((cas.loan_amount)::text || ' '::text) || cas.currency) AS loan_objective_attr_numeric,
    NULL::text AS loan_objective_attr_text,
    cas.due_date AS loan_objective_attr_time,
    NULL::text AS loan_objective_attr_json,
    gc.created_at,
    gc.modified_at,
    gc.modified_by,
    mod_np.first_name AS modified_by_first_name,
    mod_np.last_name AS modified_by_last_name,
    gc.is_locked,
    gc.notes,
    cas.loan_amount,
    cas.currency,
    cas.due_date,
    cpa.is_installment_calendar,
    cpa.principal_amount,
    cpb.principal_balance,
    cpb.overdue_amount
   FROM (((((((((public.loan gc
     JOIN public.loan_type ct ON ((ct.loan_type_id = gc.loan_type_id)))
     JOIN public.loan_status cs ON ((cs.loan_status_id = gc.loan_status_id)))
     JOIN public.natural_person owner_np ON (((owner_np.person_id)::text = (gc.owner_person_id)::text)))
     JOIN loan_attributes cas ON (((cas.loan_id)::text = (gc.loan_id)::text)))
     JOIN public.loan_principal_amount cpa ON (((cpa.loan_id)::text = (gc.loan_id)::text)))
     JOIN public.loan_principal_balance cpb ON (((cpb.loan_id)::text = (gc.loan_id)::text)))
     LEFT JOIN public.natural_person assessor_np ON (((assessor_np.person_id)::text = cas.referent)))
     LEFT JOIN public.natural_person guarantor_np ON (((guarantor_np.person_id)::text = cas.guarantor)))
     LEFT JOIN public.natural_person mod_np ON (((mod_np.person_id)::text = (gc.modified_by)::text)));


ALTER TABLE public.loan_list OWNER TO cmdb_user1;

--
-- Name: loan_payment_list; Type: VIEW; Schema: public; Owner: cmdb_user1
--

CREATE VIEW public.loan_payment_list AS
 WITH inst AS (
         SELECT ins.loan_id,
            ins.installment_id AS payment_id,
            ins.installment_no,
            NULL::text AS charge_id,
            ins.due_date,
            ins.amount,
            ins.currency AS currency_id,
            ipi.transaction_amount_drawn,
            ins.variable_symbol,
            NULL::text AS specific_symbol,
            NULL::text AS constant_symbol,
            ins.reminder_at,
            ins.is_valid,
            ins.config,
            'installment'::text AS payment_type,
            ipa.transaction_id,
            ipa.due_date AS transaction_due_date,
            ipa.sent_at AS transaction_sent_at,
            ipa.account_iban,
            ipa.counteraccount_iban,
            ipa.payer_name,
            ipa.payer_address,
            (percent_rank() OVER lastp = (1)::double precision) AS last_payment
           FROM ((public.installment ins
             LEFT JOIN public.incomming_payment_installment ipi ON (((ipi.installment_id = ins.installment_id) AND (NOT ipi.is_deleted))))
             LEFT JOIN public.incomming_payment ipa ON (((ipa.transaction_id)::text = (ipi.transaction_id)::text)))
          WHERE ins.is_valid
          WINDOW lastp AS (PARTITION BY ins.loan_id ORDER BY ins.due_date)
        ), chrg AS (
         SELECT cc.loan_id,
            cc.loan_charge_id AS payment_id,
            NULL::smallint AS installment_no,
            cc.charge_id,
            cc.due_date,
            cc.amount,
            cc.currency AS currency_id,
            NULL::numeric AS transaction_amount_drawn,
            cc.variable_symbol,
            cc.specific_symbol,
            cc.constant_symbol,
            cc.reminder_at,
            cc.is_valid,
            cc.config,
            COALESCE(cc.payment_type, 'other'::text) AS payment_type,
            NULL::text AS transaction_id,
            NULL::timestamp without time zone AS transaction_due_date,
            NULL::timestamp without time zone AS transaction_sent_at,
            NULL::text AS account_iban,
            NULL::text AS counteraccount_iban,
            NULL::text AS payer_name,
            NULL::text AS payer_address,
            (COALESCE((cc.config ->> 'is_initial'::text), 'false'::text))::boolean AS is_initial
           FROM public.loan_charge cc
          WHERE cc.is_valid
        ), chrg_perloan AS (
         SELECT chrg.loan_id,
            sum(chrg.amount) AS charge_amount
           FROM chrg
          WHERE ((NOT chrg.is_initial) AND chrg.is_valid)
          GROUP BY chrg.loan_id
        ), uni AS (
         SELECT un.loan_id,
            ((un.payment_type || '-'::text) || (un.payment_id)::text) AS pid,
            un.payment_id,
            un.payment_type,
            (un.due_date)::date AS due_date,
            un.due_date AS due_date_timestamp,
                CASE
                    WHEN (NOT un.last_payment) THEN un.amount
                    ELSE (round(((un.amount + COALESCE(sum(chrp.charge_amount), (0)::double precision)))::numeric, 2))::double precision
                END AS amount,
            un.currency_id,
            un.last_payment,
            (cur.attribute_value ->> 'title'::text) AS currency_title,
            (cur.attribute_value ->> 'value'::text) AS currency_value,
            un.installment_no,
            un.variable_symbol,
            un.specific_symbol,
            un.constant_symbol,
            un.reminder_at,
            un.is_valid,
            un.config,
            jsonb_agg(jsonb_build_object('transaction_id', un.transaction_id, 'transaction_due_date', (un.transaction_due_date)::date, 'transaction_due_date_timestamp', un.transaction_due_date, 'transaction_sent_at', un.transaction_sent_at, 'transaction_amount_drawn', un.transaction_amount_drawn, 'account_iban', un.account_iban, 'counteraccount_iban', un.counteraccount_iban, 'payer_name', un.payer_name, 'payer_address', un.payer_address) ORDER BY un.transaction_due_date) AS transactions,
            sum(un.transaction_amount_drawn) AS transaction_amount_sum,
                CASE
                    WHEN ((max(un.transaction_due_date) <= un.due_date) AND (un.amount <= sum(un.transaction_amount_drawn))) THEN 'paid'::text
                    WHEN ((max(un.transaction_due_date) > un.due_date) AND (un.amount <= sum(un.transaction_amount_drawn))) THEN 'paid_overdue'::text
                    WHEN (((max(un.transaction_due_date) IS NULL) OR (un.amount > sum(un.transaction_amount_drawn))) AND (now() > un.due_date)) THEN 'overdue'::text
                    ELSE 'unpaid'::text
                END AS payment_status
           FROM ((( SELECT inst.loan_id,
                    inst.payment_id,
                    inst.payment_type,
                    inst.due_date,
                    inst.amount,
                    inst.currency_id,
                    inst.transaction_amount_drawn,
                    inst.installment_no,
                    inst.variable_symbol,
                    inst.specific_symbol,
                    inst.constant_symbol,
                    inst.reminder_at,
                    inst.is_valid,
                    inst.config,
                    inst.transaction_id,
                    inst.transaction_due_date,
                    inst.transaction_sent_at,
                    inst.account_iban,
                    inst.counteraccount_iban,
                    inst.payer_name,
                    inst.payer_address,
                    false AS is_initial,
                    inst.last_payment
                   FROM inst
                UNION
                 SELECT chrg.loan_id,
                    chrg.payment_id,
                    chrg.payment_type,
                    chrg.due_date,
                    chrg.amount,
                    chrg.currency_id,
                    chrg.transaction_amount_drawn,
                    chrg.installment_no,
                    chrg.variable_symbol,
                    chrg.specific_symbol,
                    chrg.constant_symbol,
                    chrg.reminder_at,
                    chrg.is_valid,
                    chrg.config,
                    chrg.transaction_id,
                    chrg.transaction_due_date,
                    chrg.transaction_sent_at,
                    chrg.account_iban,
                    chrg.counteraccount_iban,
                    chrg.payer_name,
                    chrg.payer_address,
                    chrg.is_initial,
                    false AS last_payment
                   FROM chrg) un
             JOIN public.loan_attribute_value cur ON ((((cur.loan_attribute_value_id)::text = (un.currency_id)::text) AND (NOT cur.is_deleted))))
             LEFT JOIN chrg_perloan chrp ON ((((chrp.loan_id)::text = (un.loan_id)::text) AND (un.last_payment IS TRUE))))
          GROUP BY un.loan_id, un.payment_id, un.payment_type, un.due_date, un.amount, un.currency_id, (cur.attribute_value ->> 'title'::text), (cur.attribute_value ->> 'value'::text), un.installment_no, un.variable_symbol, un.specific_symbol, un.constant_symbol, un.reminder_at, un.is_valid, un.config, un.last_payment
          ORDER BY ((un.due_date)::date), un.payment_id
        )
 SELECT uni.loan_id,
    uni.pid,
    uni.payment_id,
    uni.payment_type,
    uni.due_date,
    uni.due_date_timestamp,
    uni.amount,
    uni.currency_id,
    uni.currency_title,
    uni.currency_value,
    uni.installment_no,
    uni.variable_symbol,
    uni.reminder_at,
    uni.is_valid,
    uni.config,
    uni.transactions,
    uni.transaction_amount_sum,
    uni.payment_status,
    uni.last_payment
   FROM uni;


ALTER TABLE public.loan_payment_list OWNER TO cmdb_user1;

--
-- Name: loan_status_loan_status_id_seq; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.loan_status_loan_status_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.loan_status_loan_status_id_seq OWNER TO cmdb_user1;

--
-- Name: loan_status_loan_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cmdb_user1
--

ALTER SEQUENCE public.loan_status_loan_status_id_seq OWNED BY public.loan_status.loan_status_id;


--
-- Name: loan_type_loan_type_id_seq; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.loan_type_loan_type_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.loan_type_loan_type_id_seq OWNER TO cmdb_user1;

--
-- Name: loan_type_loan_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cmdb_user1
--

ALTER SEQUENCE public.loan_type_loan_type_id_seq OWNED BY public.loan_type.loan_type_id;


--
-- Name: charge; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.charge (
    charge_id integer NOT NULL,
    charge_name text NOT NULL,
    charge_descr text,
    charge_billing_mode_id character varying NOT NULL,
    charge_amount double precision,
    is_deleted boolean DEFAULT false NOT NULL,
    org_tags text[] DEFAULT '{}'::text[] NOT NULL
);


ALTER TABLE public.charge OWNER TO cmdb_user1;

--
-- Name: charge_billing_mode; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.charge_billing_mode (
    charge_billing_mode_id character varying NOT NULL,
    charge_billing_mode_name text NOT NULL
);


ALTER TABLE public.charge_billing_mode OWNER TO cmdb_user1;

--
-- Name: charge_loan_type; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.charge_loan_type (
    loan_type_id smallint NOT NULL,
    charge_id integer NOT NULL
);


ALTER TABLE public.charge_loan_type OWNER TO cmdb_user1;

--
-- Name: charge_charge_id_seq; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.charge_charge_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.charge_charge_id_seq OWNER TO cmdb_user1;

--
-- Name: charge_charge_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cmdb_user1
--

ALTER SEQUENCE public.charge_charge_id_seq OWNED BY public.charge.charge_id;


--
-- Name: crz_contract; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.crz_contract (
    crz_contract_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    loan_id character varying(36),
    file_name text NOT NULL,
    file_relpath text NOT NULL,
    file_hash character varying(32) NOT NULL,
    file_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(36),
    is_published boolean DEFAULT false NOT NULL,
    last_published timestamp without time zone,
    template_file_id character varying(36)
);


ALTER TABLE public.crz_contract OWNER TO cmdb_user1;

--
-- Name: document_template; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.document_template (
    template_id character varying(50) NOT NULL,
    template_name text NOT NULL,
    template_descr text,
    template_category_id character varying(36),
    template_tags text[] DEFAULT '{}'::text[] NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(36) NOT NULL
);


ALTER TABLE public.document_template OWNER TO cmdb_user1;

--
-- Name: document_template_loan_type; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.document_template_loan_type (
    loan_type_id smallint NOT NULL,
    template_id character varying(50) NOT NULL
);


ALTER TABLE public.document_template_loan_type OWNER TO cmdb_user1;

--
-- Name: document_template_file; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.document_template_file (
    template_file_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    template_id character varying(50) NOT NULL,
    template_version smallint DEFAULT 1 NOT NULL,
    file_name text NOT NULL,
    file_path text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(36) NOT NULL
);


ALTER TABLE public.document_template_file OWNER TO cmdb_user1;

--
-- Name: current_template_version; Type: VIEW; Schema: public; Owner: cmdb_user1
--

CREATE VIEW public.current_template_version AS
 WITH max_tpl_version AS (
         SELECT dt.template_category_id,
            dtf_1.template_id,
            max(dtf_1.template_version) AS template_version
           FROM (public.document_template_file dtf_1
             JOIN public.document_template dt ON (((dt.template_id)::text = (dtf_1.template_id)::text)))
          GROUP BY dt.template_category_id, dtf_1.template_id
        ), tpl_ctype AS (
         SELECT dtct.template_id,
            array_agg(dtct.loan_type_id) AS loan_type_id
           FROM public.document_template_loan_type dtct
          GROUP BY dtct.template_id
        )
 SELECT mtv.template_id,
    mtv.template_category_id,
    mtv.template_version,
    tpc.loan_type_id,
    dtf.template_file_id,
    dtf.file_path,
    dtf.file_name
   FROM ((max_tpl_version mtv
     JOIN public.document_template_file dtf ON ((((dtf.template_id)::text = (mtv.template_id)::text) AND (dtf.template_version = mtv.template_version))))
     LEFT JOIN tpl_ctype tpc ON (((tpc.template_id)::text = (mtv.template_id)::text)));


ALTER TABLE public.current_template_version OWNER TO cmdb_user1;

--
-- Name: debt_writeoff_type; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.debt_writeoff_type (
    writeoff_type_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    writeoff_type_label text NOT NULL,
    writeoff_type_descr text
);


ALTER TABLE public.debt_writeoff_type OWNER TO cmdb_user1;

--
-- Name: edu_organization_type; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.edu_organization_type (
    edu_organization_type_id smallint NOT NULL,
    edu_organization_type_name text NOT NULL
);


ALTER TABLE public.edu_organization_type OWNER TO cmdb_user1;

--
-- Name: edu_organization_type_edu_organization_type_id_seq; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.edu_organization_type_edu_organization_type_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.edu_organization_type_edu_organization_type_id_seq OWNER TO cmdb_user1;

--
-- Name: edu_organization_type_edu_organization_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cmdb_user1
--

ALTER SEQUENCE public.edu_organization_type_edu_organization_type_id_seq OWNED BY public.edu_organization_type.edu_organization_type_id;


--
-- Name: form_config_param; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.form_config_param (
    form_config_param_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    form_config_param_label text NOT NULL,
    loan_type_id smallint,
    param_datatype text DEFAULT 'float'::text NOT NULL,
    is_public boolean DEFAULT false NOT NULL
);


ALTER TABLE public.form_config_param OWNER TO cmdb_user1;

--
-- Name: form_config_param_value; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.form_config_param_value (
    form_config_param_value_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    form_config_param_id character varying(36) NOT NULL,
    value jsonb DEFAULT '{}'::jsonb NOT NULL
);


ALTER TABLE public.form_config_param_value OWNER TO cmdb_user1;

--
-- Name: incomming_mail; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.incomming_mail (
    mail_id bigint NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    sent_at timestamp without time zone,
    sender character varying(36),
    sender_address text,
    sender_city text,
    sender_zip character varying,
    sender_country text,
    loan_id character varying(36),
    attachment_path character varying(512),
    attachment_title character varying(512),
    message text,
    config jsonb
);


ALTER TABLE public.incomming_mail OWNER TO cmdb_user1;

--
-- Name: incomming_mail_loan_event; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.incomming_mail_loan_event (
    mail_id bigint NOT NULL,
    loan_event_id character varying(36) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(36) NOT NULL
);


ALTER TABLE public.incomming_mail_loan_event OWNER TO cmdb_user1;

--
-- Name: incomming_mail_mail_id_seq; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.incomming_mail_mail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.incomming_mail_mail_id_seq OWNER TO cmdb_user1;

--
-- Name: incomming_mail_mail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cmdb_user1
--

ALTER SEQUENCE public.incomming_mail_mail_id_seq OWNED BY public.incomming_mail.mail_id;


--
-- Name: incomming_payment_loan_charge; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.incomming_payment_loan_charge (
    transaction_id character varying(512) NOT NULL,
    loan_charge_id bigint NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(36) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    transaction_amount_drawn double precision NOT NULL
);


ALTER TABLE public.incomming_payment_loan_charge OWNER TO cmdb_user1;

--
-- Name: installment_installment_id_seq; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.installment_installment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.installment_installment_id_seq OWNER TO cmdb_user1;

--
-- Name: installment_installment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cmdb_user1
--

ALTER SEQUENCE public.installment_installment_id_seq OWNED BY public.installment.installment_id;


--
-- Name: mail_queue; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.mail_queue (
    mail_queue_id bigint NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    send_at timestamp without time zone DEFAULT now(),
    subject text NOT NULL,
    message text NOT NULL,
    send_to text NOT NULL,
    created_by character varying(36),
    sent boolean DEFAULT false NOT NULL,
    smtp_response jsonb,
    notification_queue_id bigint NOT NULL,
    config jsonb,
    is_system boolean DEFAULT true NOT NULL
);


ALTER TABLE public.mail_queue OWNER TO cmdb_user1;

--
-- Name: mail_queue_mail_queue_id_seq; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.mail_queue_mail_queue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.mail_queue_mail_queue_id_seq OWNER TO cmdb_user1;

--
-- Name: mail_queue_mail_queue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cmdb_user1
--

ALTER SEQUENCE public.mail_queue_mail_queue_id_seq OWNED BY public.mail_queue.mail_queue_id;


--
-- Name: natural_person_attribute; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.natural_person_attribute (
    person_id character varying(36) NOT NULL,
    person_attribute_type_id character varying(36) NOT NULL,
    valid_from timestamp without time zone DEFAULT now() NOT NULL,
    valid_to timestamp without time zone,
    created_by character varying(36) NOT NULL,
    deleted_by character varying(36),
    attribute_value jsonb DEFAULT '{"value": 0}'::jsonb NOT NULL
);


ALTER TABLE public.natural_person_attribute OWNER TO cmdb_user1;

--
-- Name: natural_person_list; Type: VIEW; Schema: public; Owner: cmdb_user1
--

CREATE VIEW public.natural_person_list AS
 SELECT np.person_id,
    np.personal_identification_number,
    np.first_name,
    np.last_name,
    np.title_before AS title,
    np.title_before,
    np.date_of_birth,
    np.nationality,
    np.address,
    np.correspondence_address,
    np.email,
    np.phone_number,
    np.created_at,
    np.last_modified,
    np.preference,
    np.is_service_account,
    np.title_after
   FROM public.natural_person np;


ALTER TABLE public.natural_person_list OWNER TO cmdb_user1;

--
-- Name: notification; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.notification (
    notification_id integer NOT NULL,
    notification_name character varying(30) NOT NULL,
    notification_desc character varying(300),
    notification_type_id smallint NOT NULL,
    subject text,
    message text NOT NULL,
    html_message boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(36) NOT NULL,
    modified_at timestamp without time zone DEFAULT now() NOT NULL,
    modified_by character varying(36) NOT NULL,
    default_phone_number text[],
    default_email text[]
);


ALTER TABLE public.notification OWNER TO cmdb_user1;

--
-- Name: notification_notification_id_seq; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.notification_notification_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notification_notification_id_seq OWNER TO cmdb_user1;

--
-- Name: notification_notification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cmdb_user1
--

ALTER SEQUENCE public.notification_notification_id_seq OWNED BY public.notification.notification_id;


--
-- Name: notification_queue; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.notification_queue (
    notification_queue_id bigint NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    send_at timestamp without time zone DEFAULT now() NOT NULL,
    addressee character varying(36) NOT NULL,
    subject text,
    message text NOT NULL,
    html_message boolean NOT NULL,
    notification_type_id smallint NOT NULL,
    sender_address text,
    notification_id integer,
    sent boolean DEFAULT false NOT NULL,
    process_type_id character varying(36) NOT NULL,
    des_guid character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    loan_id character varying(36)
);


ALTER TABLE public.notification_queue OWNER TO cmdb_user1;

--
-- Name: COLUMN notification_queue.des_guid; Type: COMMENT; Schema: public; Owner: cmdb_user1
--

COMMENT ON COLUMN public.notification_queue.des_guid IS 'PodanieID';


--
-- Name: notification_queue_notification_queue_id_seq; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.notification_queue_notification_queue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notification_queue_notification_queue_id_seq OWNER TO cmdb_user1;

--
-- Name: notification_queue_notification_queue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cmdb_user1
--

ALTER SEQUENCE public.notification_queue_notification_queue_id_seq OWNED BY public.notification_queue.notification_queue_id;


--
-- Name: notification_type; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.notification_type (
    notification_type_id smallint NOT NULL,
    notification_type_name character varying(30) NOT NULL,
    allow_html_message boolean DEFAULT false NOT NULL
);


ALTER TABLE public.notification_type OWNER TO cmdb_user1;


--
-- Name: person_attribute_type; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.person_attribute_type (
    person_attribute_type_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    person_attribute_type_label text NOT NULL,
    person_attribute_type_datatype text NOT NULL,
    is_reference boolean DEFAULT false NOT NULL,
    reference_type text,
    reference_table text,
    reference_table_pk text,
    reference_table_columns text[],
    person_attribute_design jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    deleted_by character varying(36),
    deleted_at timestamp without time zone
);


ALTER TABLE public.person_attribute_type OWNER TO cmdb_user1;

--
-- Name: person_attribute_list_all; Type: VIEW; Schema: public; Owner: cmdb_user1
--

CREATE VIEW public.person_attribute_list_all AS
 SELECT npa.person_id,
    npa.valid_from,
    npa.valid_to,
    npa.created_by,
    pat.person_attribute_type_id AS attribute_type_id,
    pat.person_attribute_type_label AS attribute_label,
    pat.person_attribute_type_datatype AS attribute_datatype,
    pat.person_attribute_design AS attribute_design,
        CASE
            WHEN (pat.is_reference IS TRUE) THEN public.get_person_attribute_value(pat.reference_type, pat.reference_table, COALESCE(pat.reference_table_pk, ''::text), COALESCE(pat.reference_table_columns, '{}'::text[]), npa.attribute_value)
            ELSE npa.attribute_value
        END AS attribute_value,
    pat.is_reference,
    pat.reference_type
   FROM (public.natural_person_attribute npa
     JOIN public.person_attribute_type pat ON (((pat.person_attribute_type_id)::text = (npa.person_attribute_type_id)::text)));


ALTER TABLE public.person_attribute_list_all OWNER TO cmdb_user1;

--
-- Name: person_attribute_value; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.person_attribute_value (
    person_attribute_value_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    person_attribute_type_id character varying(36) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    deleted_at timestamp without time zone,
    deleted_by character varying(36),
    attribute_value jsonb DEFAULT '{"value": 0}'::jsonb NOT NULL
);


ALTER TABLE public.person_attribute_value OWNER TO cmdb_user1;

--
-- Name: process_type; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.process_type (
    process_type_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    process_type_label text NOT NULL,
    process_type_descr text,
    has_attached_value boolean NOT NULL
);


ALTER TABLE public.process_type OWNER TO cmdb_user1;

--
-- Name: sp_out_transaction; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.sp_out_transaction (
    transaction_id integer NOT NULL,
    loan_id character varying(36) NOT NULL,
    due_date date NOT NULL,
    amount double precision NOT NULL,
    currency character varying(3) DEFAULT 'EUR'::character varying NOT NULL,
    variable_symbol character varying(10) NOT NULL,
    specific_symbol character varying,
    constant_symbol character varying,
    person_id character varying(36) NOT NULL,
    iban character varying(34) NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    address jsonb DEFAULT '{}'::jsonb NOT NULL,
    message text,
    payment_order_id integer
);


ALTER TABLE public.sp_out_transaction OWNER TO cmdb_user1;

--
-- Name: sp_out_transaction_transaction_id_seq; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.sp_out_transaction_transaction_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sp_out_transaction_transaction_id_seq OWNER TO cmdb_user1;

--
-- Name: sp_out_transaction_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cmdb_user1
--

ALTER SEQUENCE public.sp_out_transaction_transaction_id_seq OWNED BY public.sp_out_transaction.transaction_id;


--
-- Name: sp_payment_order; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.sp_payment_order (
    payment_order_id integer NOT NULL,
    payment_number smallint NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    payment_order_xml xml NOT NULL,
    auto_process boolean DEFAULT true NOT NULL,
    downloaded boolean DEFAULT false NOT NULL,
    processed boolean DEFAULT false NOT NULL,
    processed_at timestamp without time zone,
    processed_by character varying(36),
    created_date date DEFAULT (now())::date NOT NULL
);


ALTER TABLE public.sp_payment_order OWNER TO cmdb_user1;

--
-- Name: sp_payment_order_payment_order_id_seq; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.sp_payment_order_payment_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sp_payment_order_payment_order_id_seq OWNER TO cmdb_user1;

--
-- Name: sp_payment_order_payment_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cmdb_user1
--

ALTER SEQUENCE public.sp_payment_order_payment_order_id_seq OWNED BY public.sp_payment_order.payment_order_id;


--
-- Name: task_queue; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.task_queue (
    task_queue_id character varying(36) DEFAULT gen_random_uuid() NOT NULL,
    loan_id character varying(36) NOT NULL,
    owner_person_id character varying(36),
    process_type_id character varying(36) NOT NULL,
    custom_process_type_label text,
    assessor_person_id character varying(36),
    attached_value text,
    attached_value_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    approval_result boolean,
    approved_at timestamp without time zone,
    approved_by character varying(36),
    auto_approved boolean DEFAULT false NOT NULL,
    processed boolean
);


ALTER TABLE public.task_queue OWNER TO cmdb_user1;

--
-- Name: transaction_status; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.transaction_status (
    transaction_status_id smallint NOT NULL,
    transaction_status_name character varying(30) NOT NULL,
    transaction_status_descr text NOT NULL
);


ALTER TABLE public.transaction_status OWNER TO cmdb_user1;

--
-- Name: transaction_status_transaction_status_id_seq; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.transaction_status_transaction_status_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transaction_status_transaction_status_id_seq OWNER TO cmdb_user1;

--
-- Name: transaction_status_transaction_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cmdb_user1
--

ALTER SEQUENCE public.transaction_status_transaction_status_id_seq OWNED BY public.transaction_status.transaction_status_id;


--
-- Name: user_role; Type: TABLE; Schema: public; Owner: cmdb_user1
--

CREATE TABLE public.user_role (
    role_id smallint NOT NULL,
    role_name text NOT NULL,
    config jsonb DEFAULT '{"class": "badge badge-light-dark"}'::jsonb
);


ALTER TABLE public.user_role OWNER TO cmdb_user1;

--
-- Name: user_role_role_id_seq; Type: SEQUENCE; Schema: public; Owner: cmdb_user1
--

CREATE SEQUENCE public.user_role_role_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_role_role_id_seq OWNER TO cmdb_user1;

--
-- Name: user_role_role_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cmdb_user1
--

ALTER SEQUENCE public.user_role_role_id_seq OWNED BY public.user_role.role_id;


--
-- Name: loan_charge loan_charge_id; Type: DEFAULT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_charge ALTER COLUMN loan_charge_id SET DEFAULT nextval('public.loan_charge_loan_charge_id_seq'::regclass);


--
-- Name: loan_event_type loan_event_type_id; Type: DEFAULT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_event_type ALTER COLUMN loan_event_type_id SET DEFAULT nextval('public.loan_event_type_loan_event_type_id_seq'::regclass);


--
-- Name: loan_status loan_status_id; Type: DEFAULT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_status ALTER COLUMN loan_status_id SET DEFAULT nextval('public.loan_status_loan_status_id_seq'::regclass);


--
-- Name: loan_type loan_type_id; Type: DEFAULT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_type ALTER COLUMN loan_type_id SET DEFAULT nextval('public.loan_type_loan_type_id_seq'::regclass);


--
-- Name: charge charge_id; Type: DEFAULT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.charge ALTER COLUMN charge_id SET DEFAULT nextval('public.charge_charge_id_seq'::regclass);


--
-- Name: edu_organization_type edu_organization_type_id; Type: DEFAULT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.edu_organization_type ALTER COLUMN edu_organization_type_id SET DEFAULT nextval('public.edu_organization_type_edu_organization_type_id_seq'::regclass);


--
-- Name: incomming_mail mail_id; Type: DEFAULT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_mail ALTER COLUMN mail_id SET DEFAULT nextval('public.incomming_mail_mail_id_seq'::regclass);


--
-- Name: installment installment_id; Type: DEFAULT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.installment ALTER COLUMN installment_id SET DEFAULT nextval('public.installment_installment_id_seq'::regclass);


--
-- Name: mail_queue mail_queue_id; Type: DEFAULT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.mail_queue ALTER COLUMN mail_queue_id SET DEFAULT nextval('public.mail_queue_mail_queue_id_seq'::regclass);


--
-- Name: notification notification_id; Type: DEFAULT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.notification ALTER COLUMN notification_id SET DEFAULT nextval('public.notification_notification_id_seq'::regclass);


--
-- Name: notification_queue notification_queue_id; Type: DEFAULT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.notification_queue ALTER COLUMN notification_queue_id SET DEFAULT nextval('public.notification_queue_notification_queue_id_seq'::regclass);


--
-- Name: sp_out_transaction transaction_id; Type: DEFAULT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.sp_out_transaction ALTER COLUMN transaction_id SET DEFAULT nextval('public.sp_out_transaction_transaction_id_seq'::regclass);


--
-- Name: sp_payment_order payment_order_id; Type: DEFAULT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.sp_payment_order ALTER COLUMN payment_order_id SET DEFAULT nextval('public.sp_payment_order_payment_order_id_seq'::regclass);


--
-- Name: transaction_status transaction_status_id; Type: DEFAULT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.transaction_status ALTER COLUMN transaction_status_id SET DEFAULT nextval('public.transaction_status_transaction_status_id_seq'::regclass);


--
-- Name: user_role role_id; Type: DEFAULT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.user_role ALTER COLUMN role_id SET DEFAULT nextval('public.user_role_role_id_seq'::regclass);


--
-- Data for Name: attachment_category; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.attachment_category (attachment_category_id, attachment_category_name, attachment_category_descr, is_deleted) FROM stdin;
fa850bdd-e9cb-4b1d-a779-31d46404b80f	Potvrdenie o štúdiu (VŠ)	Potvrdenie o štúdiu na VŠ	f
6d1f04f9-bdd8-497e-8953-95d1bdb12a19	Potvrdenie o štúdiu (SŠ)	Potvrdenie o štúdiu na SŠ	f
e20fe193-cd0d-43f9-ae53-deec06ef007d	Potvrdenie o účelovom použití pôžičky	Potvrdenie o účelovom použití pôžičky	f
286f4807-9712-490f-850e-ebd080657293	Potvrdenie o ukončení štúdia	Potvrdenie o ukončení štúdia	f
510075a0-8fa3-4cca-9086-693ab2705782	Oznamenie klientovi	Oznamenie	f
88b54386-3868-4d33-af50-d7b1ffde005c	Výzva pre klienta	Výzva 	f
716101da-7536-44b1-a624-3f5ffdc2210d	Upozornenie klientovi	Upozornenie	f
d34d96fc-b9db-4fcb-a3df-1171c37082fa	Potvrdenie	Potvrdenie	f
9bc0b0ef-2bf6-4ae4-abc5-76e4fc6c496c	Zmluva podpísaná klientom	Zmluva podpísaná a vrátená klinetom	f
210395e8-0860-4ff8-bfb0-46fb8e797117	Zmluva o pôžičke	Zmluva o pôžicke podpísaná riaditeľom	f
16c50f2b-9ca5-45e5-9c65-06a2695a28f7	Oznamenie klientovi - Odpis	Oznamenie klientovi o odpise pôžicky	f
90314200-a289-49d3-b8e3-917f80478d8e	Oznamenie klientovi - Poplatok	Oznamenie klientovi o naúčtovaní poplatku	f
\.


--
-- Data for Name: loan; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.loan (loan_id, loan_number, loan_title, loan_description, loan_type_id, loan_status_id, owner_person_id, created_at, modified_at, modified_by, is_locked, notes) FROM stdin;
e51843f6-dcb4-41b6-bc9d-3f138cc1241e	2023010001	Test - stabilizacna pozicka 1	\N	1	1	daaadcc3-0351-4010-a698-2f9b13fd3787	2023-11-01 13:15:36.988093	2023-11-01 13:15:36.988093	6215a6db61aa71daa3275504257a8a8c	f	\N
\.


--
-- Data for Name: loan_attribute; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.loan_attribute (loan_id, loan_attribute_type_id, valid_from, valid_to, created_by, deleted_by, attribute_value) FROM stdin;
e51843f6-dcb4-41b6-bc9d-3f138cc1241e	01675211-6e9b-442f-8886-1fffc5d62934	2023-11-01 13:36:20.122045	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": "ed675cbc-facd-49d7-9655-c5649ea9da48"}
e51843f6-dcb4-41b6-bc9d-3f138cc1241e	b33702f4-635d-4ba9-b5ba-14fe448001c1	2023-11-01 13:36:20.133759	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": "6215a6db61aa71daa3275504257a8a8c"}
e51843f6-dcb4-41b6-bc9d-3f138cc1241e	1dce07e0-fb42-4f83-ad7e-7217a66e573b	2023-11-01 13:36:20.13522	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": 2000}
e51843f6-dcb4-41b6-bc9d-3f138cc1241e	5eb4d34d-ac76-4ae1-b51a-66cc90e176a2	2023-11-01 13:36:20.136467	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": "2030-01-31"}
e51843f6-dcb4-41b6-bc9d-3f138cc1241e	65d54fa2-0370-46aa-8288-73566f44e665	2023-11-01 13:36:20.137526	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": "07d4af97-4dce-477b-bc0d-b63b3f631359"}
e51843f6-dcb4-41b6-bc9d-3f138cc1241e	cefdcb99-d51c-460e-aa8b-047e308b4aa2	2023-11-01 13:36:20.138517	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": "2023-11-01"}
e51843f6-dcb4-41b6-bc9d-3f138cc1241e	09162500-8c28-4a7e-a673-41ac1f6302d7	2023-11-01 13:36:20.139384	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": "2024-10-01"}
e51843f6-dcb4-41b6-bc9d-3f138cc1241e	1eb67999-2630-4390-a957-7ad8ebed3775	2023-11-01 13:36:20.140212	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": 0.35}
e51843f6-dcb4-41b6-bc9d-3f138cc1241e	a8146d92-d332-41be-90a0-ab8a2f1ce745	2023-11-01 13:36:20.141078	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": 3.5}
e51843f6-dcb4-41b6-bc9d-3f138cc1241e	acf3afd2-cc46-40a5-8378-43f90ecc86a4	2023-11-01 13:36:20.141884	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": 0}
e51843f6-dcb4-41b6-bc9d-3f138cc1241e	d72b0900-c524-4c9c-88fd-e5e695904b22	2023-11-01 13:36:20.142719	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": "2023/00001"}
\.


--
-- Data for Name: loan_attribute_type; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.loan_attribute_type (loan_attribute_type_id, loan_attribute_type_label, loan_attribute_type_datatype, is_reference, reference_type, reference_table, reference_table_pk, reference_table_columns, loan_attribute_design, is_deleted, deleted_by, deleted_at) FROM stdin;
1dce07e0-fb42-4f83-ad7e-7217a66e573b	cattr.loan_amount	float	f	\N	\N	\N	\N	{"icon_path": "finance/fin003.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
b33702f4-635d-4ba9-b5ba-14fe448001c1	cattr.referent	text	t	table	public.natural_person	person_id	{last_name,first_name}	{"link": "natural_person/detail?person_id={attribute_id}", "is_link": true, "icon_path": "maps/map006.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-1", "icon_element": "span"}	f	\N	\N
01675211-6e9b-442f-8886-1fffc5d62934	cattr.guarantor	text	t	table	public.natural_person	person_id	{last_name,first_name}	{"link": "natural_person/detail?person_id={attribute_id}", "is_link": true, "icon_path": "general/gen049.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-1", "icon_element": "span"}	f	\N	\N
2983e59e-ea26-47c6-8369-529f93876965	cattr.dependent_child	bool	f	\N	\N	\N	\N	{"icon_path": "communication/com013.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
5e16d89a-ddfc-43dc-8594-67e9559d701f	cattr.student_w_specific_needs	bool	f	\N	\N	\N	\N	{"icon_path": "medicine/med002.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
7be1710b-6976-4b38-98bb-6a783a37be51	cattr.household_in_financial_need	bool	f	\N	\N	\N	\N	{"icon_path": "abstract/abs035.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
5eb4d34d-ac76-4ae1-b51a-66cc90e176a2	cattr.due_date	date	f	\N	\N	\N	\N	{"icon_path": "arrows/arr069.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
cefdcb99-d51c-460e-aa8b-047e308b4aa2	cattr.signature_date	date	f	\N	\N	\N	\N	{"icon_path": "arrows/arr069.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
09162500-8c28-4a7e-a673-41ac1f6302d7	Začiatok splatnosti	date	f	\N	\N	\N	\N	{"icon_path": "general/gen014.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
afb232da-831b-46ce-913b-15a22b58db6c	Predpokladaný dátum ukončenia štúdia	date	f	\N	\N	\N	\N	{"icon_path": "general/gen014.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
1c62620e-acbc-46a1-be3a-e139501d515d	Splnená oznamovacia povinnosť	bool	f	\N	\N	\N	\N	{"icon_path": "communication/com003.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
2283cfe8-fea1-49c6-8be9-b4afdef8a208	RMS	float	f	\N	\N	\N	\N	{"icon_path": "finance/fin002.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
17a6b7f1-dc98-4c06-8bf8-289fb3304a32	Deň oznámenia skončenia MD/RD/štúdia	date	f	\N	\N	\N	\N	{"icon_path": "general/gen014.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
ea439491-217c-43b0-a396-f0880561591d	Dátum ukončenia pedagogickej činnosti	date	f	\N	\N	\N	\N	{"icon_path": "general/gen014.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
65d54fa2-0370-46aa-8288-73566f44e665	cattr.currency	text	t	enum	public.loan_attribute_value	\N	\N	{"icon_path": "finance/fin002.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
7dd60601-5801-41dc-b4e2-0cf2ccef9dab	Dátum začiatku odkladu splátok z dôvodu MD/RD	date	f	\N	\N	\N	\N	{"icon_path": "general/gen014.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
bc596df9-cf71-40ad-b829-55b3361aa467	Dátum konca odkladu splátok z dôvodu MD/RD	date	f	\N	\N	\N	\N	{"icon_path": "general/gen014.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
6b7aa6e2-e216-4e56-af47-bd15e4c10386	Dátum začiatku odkladu splátok z dôvodu nezamestnanosti	date	f	\N	\N	\N	\N	{"icon_path": "general/gen014.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
0f262eae-0a21-4cf0-9368-bef65f040453	Dátum konca odkladu splátok z dôvodu nezamestnanosti	date	f	\N	\N	\N	\N	{"icon_path": "general/gen014.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
8667d20d-b3e0-4a32-9b6e-f364545080b8	Deň oznámenia o úmrtí ručiteľa	date	f	\N	\N	\N	\N	{"icon_path": "general/gen014.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
34fb7dbc-b51a-4486-b3b8-dfb1ea453328	Súd	bool	f	\N	\N	\N	\N	{"icon_path": "general/gen051.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
2ed12fd5-cbb2-48a0-8741-54b6e6075a6d	Exekúcia	bool	f	\N	\N	\N	\N	{"icon_path": "general/gen051.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
7f07c2fe-f595-4dc2-89e0-b11de35026e5	Konkurz	bool	f	\N	\N	\N	\N	{"icon_path": "general/gen051.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
3aa3e13b-fdee-45a3-a662-e56a8aa1c9eb	Doručená podpísaná zmluva o pôžičke	bool	f	\N	\N	\N	\N	{"icon_path": "communication/com003.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
62cf4c2e-9015-4fa0-b562-78208b59d129	Prvožiadateľ	bool	f	\N	\N	\N	\N	{"icon_path": "communication/com013.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
d95b131b-f859-445d-997a-12854bf6560a	Doklad o skončení	bool	f	\N	\N	\N	\N	{"icon_path": "finance/fin001.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
eeed9c71-0c8b-4edb-a886-e988198faf0f	Upozornenie na začiatok splatnosti	bool	f	\N	\N	\N	\N	{"icon_path": "communication/com003.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
d9fff65b-f99e-4bea-857a-1e7200963989	Výzva na zaslanie dokladu o skončení štúdia	bool	f	\N	\N	\N	\N	{"icon_path": "communication/com003.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
7721f69c-51a5-45a1-ac48-80023b125f1a	Posledná výzva na zaslanie dokladu o skončení štúdia	bool	f	\N	\N	\N	\N	{"icon_path": "communication/com003.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
62c89f84-c44b-409a-8bda-f4cce288f241	Zdokladovaný účel	bool	f	\N	\N	\N	\N	{"icon_path": "general/gen051.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
aae096cf-8ef4-4701-aa83-1a8c9715cb6f	Vykonaný odpis pôžičky	bool	f	\N	\N	\N	\N	{"icon_path": "arrows/arr082.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
33949897-a419-4e67-8e92-55c9df4a19ed	Plynie ochranná lehota	bool	f	\N	\N	\N	\N	{"icon_path": "general/gen051.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
a1c8c778-2775-4132-9c0a-a0a4fc61199d	Ručiteľ v konkurze	bool	f	\N	\N	\N	\N	{"icon_path": "general/gen051.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
fdfcd23d-7f8a-4520-8ea8-e8bf58403ec7	Klient je insolventný	bool	f	\N	\N	\N	\N	{"icon_path": "communication/com013.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
1524e664-a803-4883-a165-9d7b15940617	Odoslaná výzva na jednorazovú úhradu zostatku dlhu	bool	f	\N	\N	\N	\N	{"icon_path": "communication/com003.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
078dc319-1ca7-4be3-9914-d3e15bcd21fc	Status študenta	bool	f	\N	\N	\N	\N	{"icon_path": "communication/com013.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
914d820f-c3de-46b9-9377-6f4c041f469a	Dátum konca odkladu splátok	date	f	\N	\N	\N	\N	{"icon_path": "general/gen014.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
ebaabed8-4ef7-4948-aab6-be3813a43835	Dátum začiatku odkladu splátok	date	f	\N	\N	\N	\N	{"icon_path": "general/gen014.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
67a3fb90-fec8-4428-9d44-e25bb39af9f6	Zmluva o pôžičke podpísaná všetkými zmluvnými stranami	bool	f	\N	\N	\N	\N	{"icon_path": "finance/fin001.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
76d9539d-ac2f-40b2-8402-cfdddf6b3797	Pridelený právny zástupca	text	t	table	public.natural_person	person_id	{last_name,first_name}	{"link": "natural_person/detail?person_id={attribute_id}", "is_link": true, "icon_path": "general/gen049.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
c26f3597-6dae-4406-b2c7-c1ddfb0ea700	Najvyššie dosiahnuté vzdelanie	text	t	enum	public.loan_attribute_value	\N	\N	{"icon_path": "general/gen051.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
6bfc794d-8aab-48fd-bd3b-4e07c5cada86	Ukončili výkon pedagogickej činnosti	bool	f	\N	\N	\N	\N	{"icon_path": "abstract/abs035.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
03e3516e-fa17-4355-bb13-24866e564038	Opätovné začatie pedagogickej činnosti	bool	f	\N	\N	\N	\N	{"icon_path": "abstract/abs035.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
6ecdfc8b-0b58-4ca9-8a17-9797e17eb15a	ID Registratúrneho spisu	int	f	\N	\N	\N	\N	{"icon_path": "abstract/abs035.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "is_checkbox": true, "icon_element": "span"}	f	\N	\N
a8146d92-d332-41be-90a0-ab8a2f1ce745	Základný úrok	float	f	\N	\N	\N	\N	{"icon_path": "abstract/abs035.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
acf3afd2-cc46-40a5-8378-43f90ecc86a4	Zvýšený úrok	float	f	\N	\N	\N	\N	{"icon_path": "abstract/abs035.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
d72b0900-c524-4c9c-88fd-e5e695904b22	Číslo Zmluvy	text	f	\N	\N	\N	\N	{"icon_path": "abstract/abs015.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
f2aaaa8d-8dd6-458e-b4c2-b424b771db5a	Počet uprednostňujúcich kritérií	int	f	\N	\N	\N	\N	{"icon_path": "arrows/arr081.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
fc628caa-8995-42d2-afa7-a03ee90b8454	Dôvod odkladu splátok pôžičky	text	t	enum	public.loan_attribute_value	\N	\N	{"icon_path": "abstract/abs035.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
1eb67999-2630-4390-a957-7ad8ebed3775	Poistná miera (%)	float	f	\N	\N	\N	\N	{"icon_path": "abstract/abs015.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
86f7b80e-addb-49e9-93e3-2aa1d556cda1	Dátum archivovania pôžičky	date	f	\N	\N	\N	\N	{"icon_path": "general/gen014.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
46c4a1e9-7542-46a4-87d4-6d38374dd954	Pôžicka bola skontrolovaná	bool	f	\N	\N	\N	\N	{"icon_path": "arrows/arr084.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
\.


--
-- Data for Name: loan_attribute_value; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.loan_attribute_value (loan_attribute_value_id, loan_attribute_type_id, is_deleted, deleted_at, deleted_by, attribute_value) FROM stdin;
fa24e605-0af3-4194-a3eb-055f96da3e75	65d54fa2-0370-46aa-8288-73566f44e665	f	\N	\N	{"title": "GBP", "value": "£"}
7b50547b-3825-4f3a-bdc4-59fcc9011e9b	65d54fa2-0370-46aa-8288-73566f44e665	f	\N	\N	{"title": "USD", "value": "$"}
07d4af97-4dce-477b-bc0d-b63b3f631359	65d54fa2-0370-46aa-8288-73566f44e665	f	\N	\N	{"title": "EUR", "value": "€", "default": true}
20132a2e-388c-49bd-be66-3fddf99f87a2	65d54fa2-0370-46aa-8288-73566f44e665	f	\N	\N	{"title": "CZK", "value": "Kč"}
57924d35-9eda-4ee2-a9d1-7351d3efb3fc	c26f3597-6dae-4406-b2c7-c1ddfb0ea700	f	\N	\N	{"title": "úplné stredoškolské odborné s maturitou", "value": "SŠ s maturitou"}
5850201f-4d59-41dc-8879-c30c8c624109	c26f3597-6dae-4406-b2c7-c1ddfb0ea700	f	\N	\N	{"title": "úplné stredoškolské všeobecné", "value": "gymnázium, SVŠ"}
fae7996e-6d05-456d-9129-bf3b106832fd	c26f3597-6dae-4406-b2c7-c1ddfb0ea700	f	\N	\N	{"title": "vysoká škola - bakalárske", "value": "VŠ - bakalárske"}
6171a185-9694-4248-818b-a0529e854aeb	c26f3597-6dae-4406-b2c7-c1ddfb0ea700	f	\N	\N	{"title": "vysoká škola - magisterské", "value": "VŠ - magisterské"}
9ddb8f28-9b69-4f97-a28c-050d38a4ce90	c26f3597-6dae-4406-b2c7-c1ddfb0ea700	f	\N	\N	{"title": "postgraduálne štúdium", "value": "VŠ - postgraduálne"}
6cb6f3c5-86c0-4447-8603-99b9910b0ad5	fc628caa-8995-42d2-afa7-a03ee90b8454	f	\N	\N	{"title": "Odklad splátok pôžičky z dôvodu štúdia", "value": "Štúdium", "default": true}
a1f130f2-3510-4ffe-b873-dbd879bebb46	fc628caa-8995-42d2-afa7-a03ee90b8454	f	\N	\N	{"title": "Odklad splátok pôžičky z dôvodu MD/RD", "value": "MD/RD"}
55aadcca-adae-424d-b2b5-ea6c2cfbb581	fc628caa-8995-42d2-afa7-a03ee90b8454	f	\N	\N	{"title": "Odklad splátok pôžičky z iného kvalifikovaného dôvodu", "value": "Iný kvalifikovaný dôvod"}
bccf6389-5376-49ea-8e66-4b94b38ab021	fc628caa-8995-42d2-afa7-a03ee90b8454	f	\N	\N	{"title": "Ososbitný odklad splátok pôžičky", "value": "Osobitný odklad"}
4ff856a8-44ca-40b9-847e-5e9b1667cffd	fc628caa-8995-42d2-afa7-a03ee90b8454	f	\N	\N	{"title": "Odklad splátok pôžičky z dôvodu nezamestnanosti", "value": "Nezamestnanosť"}
\.


--
-- Data for Name: loan_charge; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.loan_charge (loan_charge_id, loan_id, charge_id, due_date, amount, currency, variable_symbol, specific_symbol, constant_symbol, reminder_at, is_valid, config, payment_type) FROM stdin;
\.


--
-- Data for Name: loan_event; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.loan_event (loan_event_id, loan_id, parent_loan_event, person_id, created_at, modified_at, is_deleted, loan_event_type_id, subject, message, attachment_path, attachment_title, old_event_value_int, old_event_value_json, new_event_value_int, new_event_value_json, tags) FROM stdin;
9f1c2507-a3e6-40ec-bbb9-1ee95ac17de6	e51843f6-dcb4-41b6-bc9d-3f138cc1241e	\N	6215a6db61aa71daa3275504257a8a8c	2023-11-01 13:57:44.249415	\N	f	4	\N	\N	e51843f6-dcb4-41b6-bc9d-3f138cc1241e/1bfc53ad-5658-489f-a65b-39eb0343e944.docx	Dokument.docx	\N	\N	\N	{"file_size": "71.61 KiB", "registry_record_id": "284", "registry_document_id": "-2147472639", "attachment_category_id": null, "registry_document_number": "175/2023"}	{}
4a69236a-5542-4cf4-a918-fbf8f679b613	e51843f6-dcb4-41b6-bc9d-3f138cc1241e	\N	daaadcc3-0351-4010-a698-2f9b13fd3787	2023-11-01 14:01:00.781651	\N	f	3	Komentar	Komentar od klienta	\N	\N	\N	\N	\N	\N	{}
\.


--
-- Data for Name: loan_event_type; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.loan_event_type (loan_event_type_id, loan_event_type_name, loan_event_type_message, has_attachment, is_attribute_change, loan_event_design) FROM stdin;
0	loan-event-type.loan-created	cevent.loan-created	f	f	{"icon_path": "abstract/abs024.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-2 svg-icon-gray-500", "icon_element": "span"}
1	loan-event-type.loan-status-change	cevent.loan-status-changed	f	t	{"icon_path": "maps/map003.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-2 svg-icon-gray-500", "icon_element": "span"}
2	loan-event-type.dattribute-change	cevent.dynamic-attr-changed	f	t	{"icon_path": "abstract/abs008.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-2 svg-icon-gray-500", "icon_element": "span"}
3	loan-event-type.comment	cevent.comment	f	f	{"icon_path": "communication/com003.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-2 svg-icon-gray-500", "icon_element": "span"}
4	loan-event-type.uploaded-attachment	cevent.uploaded-attachment	t	f	{"icon_path": "files/fil022.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-2 svg-icon-gray-500", "icon_element": "span"}
5	loan-event-type.loan-title-change	cevent.loan-title-changed	f	f	{"icon_path": "text/txt005.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-2 svg-icon-gray-500", "icon_element": "span"}
6	loan-event-type.charged-fee	cevent.charged-fee	f	f	{"icon_path": "finance/fin003.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-2 svg-icon-gray-500", "icon_element": "span"}
7	loan-event-type.debt-writeoff	cevent.debt-writeoff	f	f	{"icon_path": "finance/fin003.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-2 svg-icon-gray-500", "icon_element": "span"}
8	loan-event-type.removed-charged-fee	cevent.removed-charged-fee	f	f	{"icon_path": "finance/fin003.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-2 svg-icon-gray-500", "icon_element": "span"}
10	loan-event-type.loan-funds-provided	cevent.loan-funds-provided-to-client	f	f	{"icon_path": "finance/fin003.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-2 svg-icon-gray-500", "icon_element": "span"}
11	loan-event-type.removed-document	cevent.removed-loan-document	f	f	{"icon_path": "general/gen027.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-2 svg-icon-gray-500", "icon_element": "span"}
12	loan-event-type.client-request-delete-file	cevent.client-request-delete-file	f	f	{"icon_path": "general/gen046.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-2 svg-icon-gray-500", "icon_element": "span"}
9	loan-event-type.contract-publish-crz	cevent.contract-published-to-crz	f	f	{"icon_path": "finance/fin001.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-2 svg-icon-gray-500", "icon_element": "span"}
13	loan-event-type.payment-sent-to-client	cevent.payment-sent-to-client	f	f	{"icon_path": "finance/fin003.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-2 svg-icon-gray-500", "icon_element": "span"}
\.


--
-- Data for Name: loan_status; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.loan_status (loan_status_id, loan_status_label, loan_status_descr) FROM stdin;
1	loan-status.new	loan-status.new-descr
10	loan-status.closed	loan-status.closed-descr
2	loan-status.approved	loan-status.approved-descr
3	loan-status.suspended	loan-status.suspended-descr
4	loan-status.denied	loan-status.denied-descr
6	loan-status.unauth	loan-status.unauth-descr
7	loan-status.extorted	loan-status.extorted-descr
8	loan-status.uncollectible	loan-status.uncollectible-descr
9	loan-status.archived	loan-status.archived-decr
11	loan-status.moved-to-next-term	loan-status.moved-to-next-term-descr
12	loan-status.waiting-paper-application	loan-status.waiting-paper-application-descr
13	loan-status.waiting-board-approval	loan-status.waiting-board-approval-descr
14	loan-status.waiting-client-signature	loan-status.waiting-client-signature-descr
15	loan-status.pending-funds-payoff	loan-status.pending-funds-payoff-descr
5	loan-status.funds-paid-off	loan-status.funds-paid-off-descr
\.


--
-- Data for Name: loan_type; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.loan_type (loan_type_id, loan_type_label, loan_type_descr, loan_type_abbr, config) FROM stdin;
1	SPO - Stabilizačná pôžička	Stabilizačná pôžička	SPO	{"class": "badge badge-light-danger"}
\.


--
-- Data for Name: loan_type_loan_attribute_type; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.loan_type_loan_attribute_type (loan_type_id, loan_attribute_type_id, is_readonly, is_audited, is_named_attribute, relative_order, is_optional) FROM stdin;
1	b33702f4-635d-4ba9-b5ba-14fe448001c1	f	t	f	0	f
1	62c89f84-c44b-409a-8bda-f4cce288f241	t	t	f	1	f
1	1dce07e0-fb42-4f83-ad7e-7217a66e573b	t	f	t	33	t
1	65d54fa2-0370-46aa-8288-73566f44e665	t	t	t	34	f
1	5eb4d34d-ac76-4ae1-b51a-66cc90e176a2	f	t	t	35	f
1	7be1710b-6976-4b38-98bb-6a783a37be51	f	t	f	36	f
1	2983e59e-ea26-47c6-8369-529f93876965	f	t	f	37	f
1	5e16d89a-ddfc-43dc-8594-67e9559d701f	f	t	f	38	f
1	cefdcb99-d51c-460e-aa8b-047e308b4aa2	f	t	t	42	f
1	76d9539d-ac2f-40b2-8402-cfdddf6b3797	f	t	f	47	f
1	d72b0900-c524-4c9c-88fd-e5e695904b22	t	f	f	52	f
1	0f262eae-0a21-4cf0-9368-bef65f040453	f	t	f	\N	f
1	2ed12fd5-cbb2-48a0-8741-54b6e6075a6d	f	t	f	\N	f
1	7f07c2fe-f595-4dc2-89e0-b11de35026e5	f	t	f	\N	f
1	3aa3e13b-fdee-45a3-a662-e56a8aa1c9eb	f	t	f	\N	f
1	62cf4c2e-9015-4fa0-b562-78208b59d129	f	t	f	\N	f
1	d95b131b-f859-445d-997a-12854bf6560a	f	t	f	\N	f
1	eeed9c71-0c8b-4edb-a886-e988198faf0f	f	t	f	\N	f
1	d9fff65b-f99e-4bea-857a-1e7200963989	f	t	f	\N	f
1	7721f69c-51a5-45a1-ac48-80023b125f1a	f	t	f	\N	f
1	aae096cf-8ef4-4701-aa83-1a8c9715cb6f	f	t	f	\N	f
1	fdfcd23d-7f8a-4520-8ea8-e8bf58403ec7	f	t	f	\N	f
1	1524e664-a803-4883-a165-9d7b15940617	f	t	f	\N	f
1	078dc319-1ca7-4be3-9914-d3e15bcd21fc	f	t	f	\N	f
1	acf3afd2-cc46-40a5-8378-43f90ecc86a4	t	t	t	\N	f
1	09162500-8c28-4a7e-a673-41ac1f6302d7	f	t	f	\N	f
1	afb232da-831b-46ce-913b-15a22b58db6c	f	t	f	\N	f
1	1c62620e-acbc-46a1-be3a-e139501d515d	f	t	f	\N	f
1	2283cfe8-fea1-49c6-8be9-b4afdef8a208	f	t	f	\N	f
1	17a6b7f1-dc98-4c06-8bf8-289fb3304a32	f	t	f	\N	f
1	ebaabed8-4ef7-4948-aab6-be3813a43835	f	t	f	\N	f
1	914d820f-c3de-46b9-9377-6f4c041f469a	f	t	f	\N	f
1	7dd60601-5801-41dc-b4e2-0cf2ccef9dab	f	t	f	\N	f
1	bc596df9-cf71-40ad-b829-55b3361aa467	f	t	f	\N	f
1	6b7aa6e2-e216-4e56-af47-bd15e4c10386	f	t	f	\N	f
1	fc628caa-8995-42d2-afa7-a03ee90b8454	f	t	f	\N	t
1	1eb67999-2630-4390-a957-7ad8ebed3775	f	t	f	\N	f
1	46c4a1e9-7542-46a4-87d4-6d38374dd954	t	t	f	\N	t
1	a8146d92-d332-41be-90a0-ab8a2f1ce745	f	t	f	\N	f
1	01675211-6e9b-442f-8886-1fffc5d62934	f	t	f	\N	f
\.


--
-- Data for Name: charge; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.charge (charge_id, charge_name, charge_descr, charge_billing_mode_id, charge_amount, is_deleted, org_tags) FROM stdin;
26	Iné	poplatky, ktoré nie je možné zaradiť do ktorejkoľvek inej kategórie poplatkov	647400	\N	f	{FnPV}
\.


--
-- Data for Name: charge_billing_mode; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.charge_billing_mode (charge_billing_mode_id, charge_billing_mode_name) FROM stdin;
647400	647400 - Tržby poplatky - stabilizačné pôžičky NČ
\.


--
-- Data for Name: charge_loan_type; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.charge_loan_type (loan_type_id, charge_id) FROM stdin;
1	26
\.


--
-- Data for Name: crz_contract; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.crz_contract (crz_contract_id, loan_id, file_name, file_relpath, file_hash, file_deleted, created_at, created_by, is_published, last_published, template_file_id) FROM stdin;
\.


--
-- Data for Name: debt_writeoff; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.debt_writeoff (writeoff_id, loan_id, writeoff_amount, writeoff_type_id, created_at, created_by, is_valid, config) FROM stdin;
\.


--
-- Data for Name: debt_writeoff_type; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.debt_writeoff_type (writeoff_type_id, writeoff_type_label, writeoff_type_descr) FROM stdin;
392e0d85-037a-4b5a-a782-fbcbd80a734c	Odpis dlžnej čiastky	\N
\.


--
-- Data for Name: document_template; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.document_template (template_id, template_name, template_descr, template_category_id, template_tags, is_deleted, created_at, created_by) FROM stdin;
\.


--
-- Data for Name: document_template_loan_type; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.document_template_loan_type (loan_type_id, template_id) FROM stdin;
\.


--
-- Data for Name: document_template_file; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.document_template_file (template_file_id, template_id, template_version, file_name, file_path, created_at, created_by) FROM stdin;
\.


--
-- Data for Name: edu_organization_type; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.edu_organization_type (edu_organization_type_id, edu_organization_type_name) FROM stdin;
\.


--
-- Data for Name: form_config_param; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.form_config_param (form_config_param_id, form_config_param_label, loan_type_id, param_datatype, is_public) FROM stdin;
c3d173f9-56d2-4030-9fd0-a092f824782d	test param 1	1	float	t
31593b3c-c6ab-4336-bac2-1020003cb18d	test param 2	\N	int	t
fbd6fa49-1c81-4863-bd54-9fc6b9ae2a96	test param 3	\N	date	t
\.


--
-- Data for Name: form_config_param_value; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.form_config_param_value (form_config_param_value_id, form_config_param_id, value) FROM stdin;
8d177236-aeb6-4df0-a438-519870404c36	c3d173f9-56d2-4030-9fd0-a092f824782d	{"value": 1.23}
9c1a2884-fb0e-4d7c-840b-f664d5a684f2	31593b3c-c6ab-4336-bac2-1020003cb18d	{"value": 100}
3d136f37-5d90-4d83-878a-4cf5932422ef	fbd6fa49-1c81-4863-bd54-9fc6b9ae2a96	{"value": "2023-01-01"}
\.


--
-- Data for Name: incomming_mail; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.incomming_mail (mail_id, created_at, sent_at, sender, sender_address, sender_city, sender_zip, sender_country, loan_id, attachment_path, attachment_title, message, config) FROM stdin;
\.


--
-- Data for Name: incomming_mail_loan_event; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.incomming_mail_loan_event (mail_id, loan_event_id, created_at, created_by) FROM stdin;
\.


--
-- Data for Name: incomming_payment; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.incomming_payment (transaction_id, created_at, account_iban, counteraccount_iban, bic_swift, amount, currency, due_date, sent_at, variable_symbol, specific_symbol, constant_symbol, payment_purpose, payer_name, payer_address, transaction_status_id) FROM stdin;
\.


--
-- Data for Name: incomming_payment_loan_charge; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.incomming_payment_loan_charge (transaction_id, loan_charge_id, created_at, created_by, is_deleted, transaction_amount_drawn) FROM stdin;
\.


--
-- Data for Name: incomming_payment_installment; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.incomming_payment_installment (transaction_id, installment_id, created_at, created_by, is_deleted, transaction_amount_drawn) FROM stdin;
\.


--
-- Data for Name: installment; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.installment (installment_id, installment_no, loan_id, due_date, amount, currency, variable_symbol, reminder_at, is_valid, config) FROM stdin;
\.


--
-- Data for Name: mail_queue; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.mail_queue (mail_queue_id, created_at, send_at, subject, message, send_to, created_by, sent, smtp_response, notification_queue_id, config, is_system) FROM stdin;
\.


--
-- Data for Name: natural_person; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.natural_person (person_id, personal_identification_number, first_name, last_name, title_before, date_of_birth, nationality, address, correspondence_address, email, phone_number, created_at, last_modified, preference, is_service_account, title_after) FROM stdin;
6215a6db61aa71daa3275504257a8a8c	N/A	Referent	1	Mgr.	1991-12-31	slovenská	Nejaka ulica 124, 123 45 Nejake mesto	\N	ref1@domena.sk	+421902929000	2023-01-11 10:39:03.085049	2023-08-03 11:16:40.95877	\N	t	MBA
ed675cbc-facd-49d7-9655-c5649ea9da48	9001011239	Jozef	Mrkvička	Bc.	1990-01-01	slovenská	Nejaka ulica 123, 123 45 Nejake mesto	Iná ulica 54, 000 00 Mesto mesto	mrkvicka.jozef@gmail.com	+421987654321	2023-01-04 15:40:43.604922	2023-08-03 11:15:34.258279	\N	f	\N
daaadcc3-0351-4010-a698-2f9b13fd3787	9804066387	Peter	Novák	\N	1998-04-06	slovenská	Predmestská 3350/1, 010 01 Žilina	\N	novakpeter98@domena.com	+421998765432	2023-10-19 14:36:58.456033	2023-10-19 14:36:58.456033	\N	f	\N
\.


--
-- Data for Name: natural_person_attribute; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.natural_person_attribute (person_id, person_attribute_type_id, valid_from, valid_to, created_by, deleted_by, attribute_value) FROM stdin;
ed675cbc-facd-49d7-9655-c5649ea9da48	365760d7-f667-4f04-97d4-43ad9a7338b6	2023-09-27 16:00:31.682443	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": 1531}
ed675cbc-facd-49d7-9655-c5649ea9da48	9e42f155-3be9-46ec-b901-3c6ee618c835	2023-10-12 17:03:32.834411	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": {"city": "Bratislava", "street": "Nejaka ulica", "country": "SR", "number_o": "99a", "number_s": 456, "zip_code": "98765"}}
ed675cbc-facd-49d7-9655-c5649ea9da48	d9e9b71e-98b5-4710-a45d-ffdb38b623c9	2023-10-18 16:59:30.546321	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": "SK4302000000007000000002"}
ed675cbc-facd-49d7-9655-c5649ea9da48	23a667e2-cd67-424d-be08-35e47c6a405f	2023-10-18 17:46:14.298976	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": {"city": "Bratislava", "street": "Ulica", "country": "Slovenská Republika", "number_o": "2", "number_s": "123", "zip_code": "81102", "country_code": "SK"}}
daaadcc3-0351-4010-a698-2f9b13fd3787	23a667e2-cd67-424d-be08-35e47c6a405f	2023-10-19 14:39:12.719189	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": {"city": "Žilina", "street": "Predmestská", "country": "Slovenská Republika", "number_o": "1", "number_s": "3350", "zip_code": "01001", "country_code": "SK"}}
daaadcc3-0351-4010-a698-2f9b13fd3787	36eb848d-2c2b-47e2-8d50-be2ceba20d1e	2023-10-19 14:39:45.941977	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": "Novotný"}
daaadcc3-0351-4010-a698-2f9b13fd3787	619da077-4520-4968-8c66-3bc966b26f57	2023-10-19 14:40:38.726296	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": 3000951357}
daaadcc3-0351-4010-a698-2f9b13fd3787	a3b1cd00-6524-4e82-bad9-0de03e0ca5df	2023-10-19 14:41:02.452875	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": 11234567}
daaadcc3-0351-4010-a698-2f9b13fd3787	d9e9b71e-98b5-4710-a45d-ffdb38b623c9	2023-10-19 14:41:40.34676	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": "SK4302000000007067294611"}
daaadcc3-0351-4010-a698-2f9b13fd3787	5420e2f9-fd02-42eb-92bc-fb67c121a810	2023-10-19 14:45:20.929684	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": "CEKOSKBX"}
daaadcc3-0351-4010-a698-2f9b13fd3787	9e42f155-3be9-46ec-b901-3c6ee618c835	2023-10-19 14:46:22.729655	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": {"city": "Žilina", "street": "Predmestská", "country": "Slovenská Republika", "number_o": "1", "number_s": "3350", "zip_code": "01001", "country_code": "SK"}}
daaadcc3-0351-4010-a698-2f9b13fd3787	86f04248-153b-4b51-b812-46d37a5a725f	2023-10-19 14:46:22.750405	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": 15667}
daaadcc3-0351-4010-a698-2f9b13fd3787	365760d7-f667-4f04-97d4-43ad9a7338b6	2023-10-19 13:08:48.091455	\N	6215a6db61aa71daa3275504257a8a8c	\N	{"value": 1535}
\.


--
-- Data for Name: notification; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.notification (notification_id, notification_name, notification_desc, notification_type_id, subject, message, html_message, created_at, created_by, modified_at, modified_by, default_phone_number, default_email) FROM stdin;
\.


--
-- Data for Name: notification_queue; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.notification_queue (notification_queue_id, created_at, send_at, addressee, subject, message, html_message, notification_type_id, sender_address, notification_id, sent, process_type_id, des_guid, loan_id) FROM stdin;
\.


--
-- Data for Name: notification_type; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.notification_type (notification_type_id, notification_type_name, allow_html_message) FROM stdin;
0	Email	t
\.


--
-- Data for Name: person_attribute_type; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.person_attribute_type (person_attribute_type_id, person_attribute_type_label, person_attribute_type_datatype, is_reference, reference_type, reference_table, reference_table_pk, reference_table_columns, person_attribute_design, is_deleted, deleted_by, deleted_at) FROM stdin;
3e2b80a1-f1ee-4e20-a0b9-77755b3fcdb7	IIS MIS User ID	int	f	\N	\N	\N	\N	{"icon_path": "technology/teh004.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
365760d7-f667-4f04-97d4-43ad9a7338b6	IIS MIS Klient ID	int	f	\N	\N	\N	\N	{"icon_path": "communication/com013.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
23a667e2-cd67-424d-be08-35e47c6a405f	Adresa	json	f	\N	\N	\N	\N	{"icon_path": "map/map008.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
86f04248-153b-4b51-b812-46d37a5a725f	PČ Klienta	int	f	\N	\N	\N	\N	{"icon_path": "general/gen056.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
9e42f155-3be9-46ec-b901-3c6ee618c835	Korešpondenčná Adresa	json	f	\N	\N	\N	\N	{"icon_path": "map/map008.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
619da077-4520-4968-8c66-3bc966b26f57	EDUID	int	f	\N	\N	\N	\N	{"icon_path": "technology/teh004.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
a3b1cd00-6524-4e82-bad9-0de03e0ca5df	IFO	text	f	\N	\N	\N	\N	{"icon_path": "technology/teh004.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
36eb848d-2c2b-47e2-8d50-be2ceba20d1e	Rodné priezvisko	text	f	\N	\N	\N	\N	{}	f	\N	\N
d9e9b71e-98b5-4710-a45d-ffdb38b623c9	IBAN	text	f	\N	\N	\N	\N	{}	f	\N	\N
5420e2f9-fd02-42eb-92bc-fb67c121a810	BIC	text	f	\N	\N	\N	\N	{}	f	\N	\N
1a7e0720-b88e-4ade-bc26-df30ce5c2066	Insolvencia	bool	f	\N	\N	\N	\N	{"icon_path": "technology/teh004.svg", "icon_type": "duotone", "icon_class": "svg-icon svg-icon-3", "icon_element": "span"}	f	\N	\N
\.


--
-- Data for Name: person_attribute_value; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.person_attribute_value (person_attribute_value_id, person_attribute_type_id, is_deleted, deleted_at, deleted_by, attribute_value) FROM stdin;
\.


--
-- Data for Name: process_type; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.process_type (process_type_id, process_type_label, process_type_descr, has_attached_value) FROM stdin;
0	Nezaradená úloha	Nezaradená alebo iná uloha	t
\.


--
-- Data for Name: sp_out_transaction; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.sp_out_transaction (transaction_id, loan_id, due_date, amount, currency, variable_symbol, specific_symbol, constant_symbol, person_id, iban, first_name, last_name, address, message, payment_order_id) FROM stdin;
\.


--
-- Data for Name: sp_payment_order; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.sp_payment_order (payment_order_id, payment_number, created_at, payment_order_xml, auto_process, downloaded, processed, processed_at, processed_by, created_date) FROM stdin;
\.


--
-- Data for Name: task_queue; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.task_queue (task_queue_id, loan_id, owner_person_id, process_type_id, custom_process_type_label, assessor_person_id, attached_value, attached_value_json, created_at, approval_result, approved_at, approved_by, auto_approved, processed) FROM stdin;
\.


--
-- Data for Name: transaction_status; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.transaction_status (transaction_status_id, transaction_status_name, transaction_status_descr) FROM stdin;
2	nespárovaná	nesprávne spárovaná platba
1	spárovaná	správne spárovaná platba
3	mylná	mylná platba na vrátenie
0	nespracovaná	čaká na spracovanie
4	neidentifikovateľná	neidentifikovateľná platba vhodná na vrátenie
5	vrátená	platba vrátená účtovníkom
\.


--
-- Data for Name: user_role; Type: TABLE DATA; Schema: public; Owner: cmdb_user1
--

COPY public.user_role (role_id, role_name, config) FROM stdin;
2	Referent	{"class": "badge badge-light-primary"}
1	Administrátor	{"class": "badge badge-light-success"}
0	System user	{"class": "badge badge-light-dark"}
\.


--
-- Name: loan_charge_loan_charge_id_seq; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.loan_charge_loan_charge_id_seq', 18, true);


--
-- Name: loan_event_type_loan_event_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.loan_event_type_loan_event_type_id_seq', 13, true);


--
-- Name: loan_number; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.loan_number', 10, true);


--
-- Name: loan_status_loan_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.loan_status_loan_status_id_seq', 16, true);


--
-- Name: loan_type_loan_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.loan_type_loan_type_id_seq', 52, true);


--
-- Name: charge_charge_id_seq; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.charge_charge_id_seq', 35, true);


--
-- Name: edu_organization_type_edu_organization_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.edu_organization_type_edu_organization_type_id_seq', 3, false);


--
-- Name: incomming_mail_mail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.incomming_mail_mail_id_seq', 1, false);


--
-- Name: installment_installment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.installment_installment_id_seq', 660, true);


--
-- Name: mail_queue_mail_queue_id_seq; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.mail_queue_mail_queue_id_seq', 12, true);


--
-- Name: notification_notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.notification_notification_id_seq', 4, true);


--
-- Name: notification_queue_notification_queue_id_seq; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.notification_queue_notification_queue_id_seq', 38, true);


--
-- Name: sp_out_transaction_transaction_id_seq; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.sp_out_transaction_transaction_id_seq', 8, true);


--
-- Name: sp_payment_order_payment_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.sp_payment_order_payment_order_id_seq', 8, true);


--
-- Name: transaction_status_transaction_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.transaction_status_transaction_status_id_seq', 3, true);


--
-- Name: user_role_role_id_seq; Type: SEQUENCE SET; Schema: public; Owner: cmdb_user1
--

SELECT pg_catalog.setval('public.user_role_role_id_seq', 3, true);


--
-- Name: mail_queue mail_queue_pk; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.mail_queue
    ADD CONSTRAINT mail_queue_pk PRIMARY KEY (mail_queue_id);


--
-- Name: attachment_category pk_attachment_category; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.attachment_category
    ADD CONSTRAINT pk_attachment_category PRIMARY KEY (attachment_category_id);


--
-- Name: loan_attribute pk_loan_attribute; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_attribute
    ADD CONSTRAINT pk_loan_attribute PRIMARY KEY (loan_id, loan_attribute_type_id, valid_from);


--
-- Name: loan_attribute_type pk_loan_attribute_type; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_attribute_type
    ADD CONSTRAINT pk_loan_attribute_type PRIMARY KEY (loan_attribute_type_id);


--
-- Name: loan_attribute_value pk_loan_attribute_value; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_attribute_value
    ADD CONSTRAINT pk_loan_attribute_value PRIMARY KEY (loan_attribute_value_id);


--
-- Name: loan_charge pk_loan_charge; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_charge
    ADD CONSTRAINT pk_loan_charge PRIMARY KEY (loan_charge_id);


--
-- Name: loan_event pk_loan_event; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_event
    ADD CONSTRAINT pk_loan_event PRIMARY KEY (loan_event_id);


--
-- Name: loan_event_type pk_loan_event_type; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_event_type
    ADD CONSTRAINT pk_loan_event_type PRIMARY KEY (loan_event_type_id);


--
-- Name: loan_status pk_loan_status; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_status
    ADD CONSTRAINT pk_loan_status PRIMARY KEY (loan_status_id);


--
-- Name: loan_type pk_loan_type; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_type
    ADD CONSTRAINT pk_loan_type PRIMARY KEY (loan_type_id);


--
-- Name: loan_type_loan_attribute_type pk_loan_type_cat; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_type_loan_attribute_type
    ADD CONSTRAINT pk_loan_type_cat PRIMARY KEY (loan_type_id, loan_attribute_type_id);


--
-- Name: charge pk_charge; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.charge
    ADD CONSTRAINT pk_charge PRIMARY KEY (charge_id);


--
-- Name: charge_billing_mode pk_charge_billing_mode; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.charge_billing_mode
    ADD CONSTRAINT pk_charge_billing_mode PRIMARY KEY (charge_billing_mode_id);


--
-- Name: charge_loan_type pk_charge_loan_type; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.charge_loan_type
    ADD CONSTRAINT pk_charge_loan_type PRIMARY KEY (loan_type_id, charge_id);


--
-- Name: crz_contract pk_crz_contract; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.crz_contract
    ADD CONSTRAINT pk_crz_contract PRIMARY KEY (crz_contract_id);


--
-- Name: debt_writeoff pk_debt_writeoff; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.debt_writeoff
    ADD CONSTRAINT pk_debt_writeoff PRIMARY KEY (writeoff_id);


--
-- Name: debt_writeoff_type pk_debt_writeoff_type; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.debt_writeoff_type
    ADD CONSTRAINT pk_debt_writeoff_type PRIMARY KEY (writeoff_type_id);


--
-- Name: document_template pk_document_template; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.document_template
    ADD CONSTRAINT pk_document_template PRIMARY KEY (template_id);


--
-- Name: document_template_loan_type pk_document_template_loan_type; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.document_template_loan_type
    ADD CONSTRAINT pk_document_template_loan_type PRIMARY KEY (loan_type_id, template_id);


--
-- Name: document_template_file pk_document_template_file; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.document_template_file
    ADD CONSTRAINT pk_document_template_file PRIMARY KEY (template_file_id);


--
-- Name: edu_organization_type pk_edu_organization_type; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.edu_organization_type
    ADD CONSTRAINT pk_edu_organization_type PRIMARY KEY (edu_organization_type_id);


--
-- Name: form_config_param pk_form_config_param; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.form_config_param
    ADD CONSTRAINT pk_form_config_param PRIMARY KEY (form_config_param_id);


--
-- Name: form_config_param_value pk_form_config_param_value; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.form_config_param_value
    ADD CONSTRAINT pk_form_config_param_value PRIMARY KEY (form_config_param_value_id);


--
-- Name: loan pk_genloan; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan
    ADD CONSTRAINT pk_genloan PRIMARY KEY (loan_id);


--
-- Name: incomming_mail_loan_event pk_imce; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_mail_loan_event
    ADD CONSTRAINT pk_imce PRIMARY KEY (mail_id, loan_event_id, created_at);


--
-- Name: incomming_mail pk_incomming_mail; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_mail
    ADD CONSTRAINT pk_incomming_mail PRIMARY KEY (mail_id);


--
-- Name: incomming_payment pk_incomming_payment; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_payment
    ADD CONSTRAINT pk_incomming_payment PRIMARY KEY (transaction_id);


--
-- Name: installment pk_installment; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.installment
    ADD CONSTRAINT pk_installment PRIMARY KEY (installment_id);


--
-- Name: incomming_payment_loan_charge pk_ipcc; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_payment_loan_charge
    ADD CONSTRAINT pk_ipcc PRIMARY KEY (transaction_id, loan_charge_id, created_at);


--
-- Name: incomming_payment_installment pk_ipi; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_payment_installment
    ADD CONSTRAINT pk_ipi PRIMARY KEY (transaction_id, installment_id, created_at);


--
-- Name: natural_person pk_natural_person; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.natural_person
    ADD CONSTRAINT pk_natural_person PRIMARY KEY (person_id);


--
-- Name: natural_person_attribute pk_natural_person_attribute; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.natural_person_attribute
    ADD CONSTRAINT pk_natural_person_attribute PRIMARY KEY (person_id, person_attribute_type_id, valid_from);


--
-- Name: notification pk_notification_id; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT pk_notification_id PRIMARY KEY (notification_id);


--
-- Name: notification_queue pk_notification_queue_id; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.notification_queue
    ADD CONSTRAINT pk_notification_queue_id PRIMARY KEY (notification_queue_id);


--
-- Name: notification_type pk_notification_type_id; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.notification_type
    ADD CONSTRAINT pk_notification_type_id PRIMARY KEY (notification_type_id);


--
-- Name: person_attribute_type pk_person_attribute_type; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.person_attribute_type
    ADD CONSTRAINT pk_person_attribute_type PRIMARY KEY (person_attribute_type_id);


--
-- Name: person_attribute_value pk_person_attribute_value; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.person_attribute_value
    ADD CONSTRAINT pk_person_attribute_value PRIMARY KEY (person_attribute_value_id);


--
-- Name: process_type pk_process; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.process_type
    ADD CONSTRAINT pk_process PRIMARY KEY (process_type_id);


--
-- Name: sp_out_transaction pk_sp_out_transaction; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.sp_out_transaction
    ADD CONSTRAINT pk_sp_out_transaction PRIMARY KEY (transaction_id);


--
-- Name: sp_payment_order pk_sp_payment_order; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.sp_payment_order
    ADD CONSTRAINT pk_sp_payment_order PRIMARY KEY (payment_order_id);


--
-- Name: task_queue pk_task_control; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.task_queue
    ADD CONSTRAINT pk_task_control PRIMARY KEY (task_queue_id);


--
-- Name: transaction_status pk_transaction_status; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.transaction_status
    ADD CONSTRAINT pk_transaction_status PRIMARY KEY (transaction_status_id);


--
-- Name: user_role pk_user_role; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.user_role
    ADD CONSTRAINT pk_user_role PRIMARY KEY (role_id);


--
-- Name: sp_payment_order uq_payment_number; Type: CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.sp_payment_order
    ADD CONSTRAINT uq_payment_number UNIQUE (payment_number, created_date);


--
-- Name: idx_loan_event_tags; Type: INDEX; Schema: public; Owner: cmdb_user1
--

CREATE INDEX idx_loan_event_tags ON public.loan_event USING gin (tags);


--
-- Name: idx_loan_owner; Type: INDEX; Schema: public; Owner: cmdb_user1
--

CREATE INDEX idx_loan_owner ON public.loan USING btree (owner_person_id);


--
-- Name: idx_loan_status; Type: INDEX; Schema: public; Owner: cmdb_user1
--

CREATE INDEX idx_loan_status ON public.loan USING btree (loan_status_id);


--
-- Name: idx_loan_type; Type: INDEX; Schema: public; Owner: cmdb_user1
--

CREATE INDEX idx_loan_type ON public.loan USING btree (loan_type_id);


--
-- Name: uq_dtf_template_id_version; Type: INDEX; Schema: public; Owner: cmdb_user1
--

CREATE UNIQUE INDEX uq_dtf_template_id_version ON public.document_template_file USING btree (template_id, template_version);


--
-- Name: loan_attribute fk_loan_attribute_loan; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_attribute
    ADD CONSTRAINT fk_loan_attribute_loan FOREIGN KEY (loan_id) REFERENCES public.loan(loan_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: loan_attribute fk_loan_attribute_cat; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_attribute
    ADD CONSTRAINT fk_loan_attribute_cat FOREIGN KEY (loan_attribute_type_id) REFERENCES public.loan_attribute_type(loan_attribute_type_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: loan_attribute fk_loan_attribute_created_by; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_attribute
    ADD CONSTRAINT fk_loan_attribute_created_by FOREIGN KEY (created_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: loan_attribute_value fk_loan_attribute_deleted_by; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_attribute_value
    ADD CONSTRAINT fk_loan_attribute_deleted_by FOREIGN KEY (deleted_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: loan_attribute fk_loan_attribute_deleted_by; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_attribute
    ADD CONSTRAINT fk_loan_attribute_deleted_by FOREIGN KEY (deleted_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: loan_charge fk_loan_charge_loan; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_charge
    ADD CONSTRAINT fk_loan_charge_loan FOREIGN KEY (loan_id) REFERENCES public.loan(loan_id) ON UPDATE CASCADE;


--
-- Name: loan_charge fk_loan_charge_charge; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_charge
    ADD CONSTRAINT fk_loan_charge_charge FOREIGN KEY (charge_id) REFERENCES public.charge(charge_id) ON UPDATE CASCADE;


--
-- Name: loan_charge fk_loan_charge_currency; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_charge
    ADD CONSTRAINT fk_loan_charge_currency FOREIGN KEY (currency) REFERENCES public.loan_attribute_value(loan_attribute_value_id) ON UPDATE CASCADE;


--
-- Name: loan_type_loan_attribute_type fk_cat_loan_attribute_type; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_type_loan_attribute_type
    ADD CONSTRAINT fk_cat_loan_attribute_type FOREIGN KEY (loan_attribute_type_id) REFERENCES public.loan_attribute_type(loan_attribute_type_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: loan_type_loan_attribute_type fk_cat_loan_type; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_type_loan_attribute_type
    ADD CONSTRAINT fk_cat_loan_type FOREIGN KEY (loan_type_id) REFERENCES public.loan_type(loan_type_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: loan_attribute_value fk_cav_loan_attribute_type; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_attribute_value
    ADD CONSTRAINT fk_cav_loan_attribute_type FOREIGN KEY (loan_attribute_type_id) REFERENCES public.loan_attribute_type(loan_attribute_type_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: loan_event fk_ce_loan; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_event
    ADD CONSTRAINT fk_ce_loan FOREIGN KEY (loan_id) REFERENCES public.loan(loan_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: loan_event fk_ce_loan_event_type; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_event
    ADD CONSTRAINT fk_ce_loan_event_type FOREIGN KEY (loan_event_type_id) REFERENCES public.loan_event_type(loan_event_type_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: loan_event fk_ce_natural_person; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_event
    ADD CONSTRAINT fk_ce_natural_person FOREIGN KEY (person_id) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: loan_event fk_ce_parent_ce; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan_event
    ADD CONSTRAINT fk_ce_parent_ce FOREIGN KEY (parent_loan_event) REFERENCES public.loan_event(loan_event_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: charge_loan_type fk_charge_loan_type_loan_type; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.charge_loan_type
    ADD CONSTRAINT fk_charge_loan_type_loan_type FOREIGN KEY (loan_type_id) REFERENCES public.loan_type(loan_type_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: charge_loan_type fk_charge_loan_type_charge; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.charge_loan_type
    ADD CONSTRAINT fk_charge_loan_type_charge FOREIGN KEY (charge_id) REFERENCES public.charge(charge_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: charge fk_charge_charge_billing_mode; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.charge
    ADD CONSTRAINT fk_charge_charge_billing_mode FOREIGN KEY (charge_billing_mode_id) REFERENCES public.charge_billing_mode(charge_billing_mode_id) ON UPDATE CASCADE;


--
-- Name: crz_contract fk_crz_loan; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.crz_contract
    ADD CONSTRAINT fk_crz_loan FOREIGN KEY (loan_id) REFERENCES public.loan(loan_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: crz_contract fk_crz_doc_tpl_file; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.crz_contract
    ADD CONSTRAINT fk_crz_doc_tpl_file FOREIGN KEY (template_file_id) REFERENCES public.document_template_file(template_file_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: crz_contract fk_crz_natural_person; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.crz_contract
    ADD CONSTRAINT fk_crz_natural_person FOREIGN KEY (created_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: debt_writeoff fk_debt_writeoff_loan; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.debt_writeoff
    ADD CONSTRAINT fk_debt_writeoff_loan FOREIGN KEY (loan_id) REFERENCES public.loan(loan_id) ON UPDATE CASCADE;


--
-- Name: debt_writeoff fk_debt_writeoff_natural_person; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.debt_writeoff
    ADD CONSTRAINT fk_debt_writeoff_natural_person FOREIGN KEY (created_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE;


--
-- Name: debt_writeoff fk_debt_writeoff_type; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.debt_writeoff
    ADD CONSTRAINT fk_debt_writeoff_type FOREIGN KEY (writeoff_type_id) REFERENCES public.debt_writeoff_type(writeoff_type_id) ON UPDATE CASCADE;


--
-- Name: document_template fk_dt_attachment_category; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.document_template
    ADD CONSTRAINT fk_dt_attachment_category FOREIGN KEY (template_category_id) REFERENCES public.attachment_category(attachment_category_id) ON UPDATE CASCADE;


--
-- Name: document_template fk_dt_natural_person; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.document_template
    ADD CONSTRAINT fk_dt_natural_person FOREIGN KEY (created_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE;


--
-- Name: document_template_loan_type fk_dtct_loan_type; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.document_template_loan_type
    ADD CONSTRAINT fk_dtct_loan_type FOREIGN KEY (loan_type_id) REFERENCES public.loan_type(loan_type_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: document_template_loan_type fk_dtct_document_template; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.document_template_loan_type
    ADD CONSTRAINT fk_dtct_document_template FOREIGN KEY (template_id) REFERENCES public.document_template(template_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: document_template_file fk_dtf_document_template; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.document_template_file
    ADD CONSTRAINT fk_dtf_document_template FOREIGN KEY (template_id) REFERENCES public.document_template(template_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: document_template_file fk_dtf_natural_person; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.document_template_file
    ADD CONSTRAINT fk_dtf_natural_person FOREIGN KEY (created_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE;


--
-- Name: form_config_param fk_form_config_param_loan_type; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.form_config_param
    ADD CONSTRAINT fk_form_config_param_loan_type FOREIGN KEY (loan_type_id) REFERENCES public.loan_type(loan_type_id) ON UPDATE CASCADE;


--
-- Name: form_config_param_value fk_form_config_param_value_form_config_param; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.form_config_param_value
    ADD CONSTRAINT fk_form_config_param_value_form_config_param FOREIGN KEY (form_config_param_id) REFERENCES public.form_config_param(form_config_param_id) ON UPDATE CASCADE;


--
-- Name: loan fk_genloan_loan_status; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan
    ADD CONSTRAINT fk_genloan_loan_status FOREIGN KEY (loan_status_id) REFERENCES public.loan_status(loan_status_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: loan fk_genloan_loan_type; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan
    ADD CONSTRAINT fk_genloan_loan_type FOREIGN KEY (loan_type_id) REFERENCES public.loan_type(loan_type_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: loan fk_genloan_modified_by_natural_person; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan
    ADD CONSTRAINT fk_genloan_modified_by_natural_person FOREIGN KEY (modified_by) REFERENCES public.natural_person(person_id);


--
-- Name: loan fk_genloan_natural_person_owner; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.loan
    ADD CONSTRAINT fk_genloan_natural_person_owner FOREIGN KEY (owner_person_id) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: incomming_mail_loan_event fk_imce_loan_event; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_mail_loan_event
    ADD CONSTRAINT fk_imce_loan_event FOREIGN KEY (loan_event_id) REFERENCES public.loan_event(loan_event_id) ON UPDATE CASCADE;


--
-- Name: incomming_mail_loan_event fk_imce_incomming_mail; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_mail_loan_event
    ADD CONSTRAINT fk_imce_incomming_mail FOREIGN KEY (mail_id) REFERENCES public.incomming_mail(mail_id) ON UPDATE CASCADE;


--
-- Name: incomming_mail_loan_event fk_imce_natural_person; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_mail_loan_event
    ADD CONSTRAINT fk_imce_natural_person FOREIGN KEY (created_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE;


--
-- Name: incomming_mail fk_incomming_mail_loan; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_mail
    ADD CONSTRAINT fk_incomming_mail_loan FOREIGN KEY (loan_id) REFERENCES public.loan(loan_id) ON UPDATE CASCADE;


--
-- Name: incomming_mail fk_incomming_mail_natural_person; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_mail
    ADD CONSTRAINT fk_incomming_mail_natural_person FOREIGN KEY (sender) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE;


--
-- Name: incomming_payment fk_incomming_payment_currency; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_payment
    ADD CONSTRAINT fk_incomming_payment_currency FOREIGN KEY (currency) REFERENCES public.loan_attribute_value(loan_attribute_value_id) ON UPDATE CASCADE;


--
-- Name: incomming_payment fk_incomming_payment_transaction_status; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_payment
    ADD CONSTRAINT fk_incomming_payment_transaction_status FOREIGN KEY (transaction_status_id) REFERENCES public.transaction_status(transaction_status_id) ON UPDATE CASCADE;


--
-- Name: installment fk_installment_loan; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.installment
    ADD CONSTRAINT fk_installment_loan FOREIGN KEY (loan_id) REFERENCES public.loan(loan_id) ON UPDATE CASCADE;


--
-- Name: installment fk_installment_currency; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.installment
    ADD CONSTRAINT fk_installment_currency FOREIGN KEY (currency) REFERENCES public.loan_attribute_value(loan_attribute_value_id) ON UPDATE CASCADE;


--
-- Name: incomming_payment_loan_charge fk_ipcc_loan_charge; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_payment_loan_charge
    ADD CONSTRAINT fk_ipcc_loan_charge FOREIGN KEY (loan_charge_id) REFERENCES public.loan_charge(loan_charge_id) ON UPDATE CASCADE;


--
-- Name: incomming_payment_loan_charge fk_ipcc_incomming_payment; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_payment_loan_charge
    ADD CONSTRAINT fk_ipcc_incomming_payment FOREIGN KEY (transaction_id) REFERENCES public.incomming_payment(transaction_id) ON UPDATE CASCADE;


--
-- Name: incomming_payment_loan_charge fk_ipcc_natural_person; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_payment_loan_charge
    ADD CONSTRAINT fk_ipcc_natural_person FOREIGN KEY (created_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE;


--
-- Name: incomming_payment_installment fk_ipi_incomming_payment; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_payment_installment
    ADD CONSTRAINT fk_ipi_incomming_payment FOREIGN KEY (transaction_id) REFERENCES public.incomming_payment(transaction_id) ON UPDATE CASCADE;


--
-- Name: incomming_payment_installment fk_ipi_installment; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_payment_installment
    ADD CONSTRAINT fk_ipi_installment FOREIGN KEY (installment_id) REFERENCES public.installment(installment_id) ON UPDATE CASCADE;


--
-- Name: incomming_payment_installment fk_ipi_natural_person; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.incomming_payment_installment
    ADD CONSTRAINT fk_ipi_natural_person FOREIGN KEY (created_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE;


--
-- Name: natural_person_attribute fk_natural_person_attribute_loan; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.natural_person_attribute
    ADD CONSTRAINT fk_natural_person_attribute_loan FOREIGN KEY (person_id) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: natural_person_attribute fk_natural_person_attribute_cat; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.natural_person_attribute
    ADD CONSTRAINT fk_natural_person_attribute_cat FOREIGN KEY (person_attribute_type_id) REFERENCES public.person_attribute_type(person_attribute_type_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: natural_person_attribute fk_natural_person_attribute_created_by; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.natural_person_attribute
    ADD CONSTRAINT fk_natural_person_attribute_created_by FOREIGN KEY (created_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: natural_person_attribute fk_natural_person_attribute_deleted_by; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.natural_person_attribute
    ADD CONSTRAINT fk_natural_person_attribute_deleted_by FOREIGN KEY (deleted_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: notification fk_notification_created_by; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT fk_notification_created_by FOREIGN KEY (created_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE;


--
-- Name: notification fk_notification_modified_by; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT fk_notification_modified_by FOREIGN KEY (modified_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE;


--
-- Name: notification fk_notification_notification_type; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT fk_notification_notification_type FOREIGN KEY (notification_type_id) REFERENCES public.notification_type(notification_type_id) ON UPDATE CASCADE;


--
-- Name: notification_queue fk_notification_queue_natural_person; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.notification_queue
    ADD CONSTRAINT fk_notification_queue_natural_person FOREIGN KEY (addressee) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE;


--
-- Name: notification_queue fk_notification_queue_notification; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.notification_queue
    ADD CONSTRAINT fk_notification_queue_notification FOREIGN KEY (notification_id) REFERENCES public.notification(notification_id) ON UPDATE CASCADE;


--
-- Name: notification_queue fk_notification_queue_notification_type; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.notification_queue
    ADD CONSTRAINT fk_notification_queue_notification_type FOREIGN KEY (notification_type_id) REFERENCES public.notification_type(notification_type_id) ON UPDATE CASCADE;


--
-- Name: person_attribute_value fk_pav_person_attribute_type; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.person_attribute_value
    ADD CONSTRAINT fk_pav_person_attribute_type FOREIGN KEY (person_attribute_type_id) REFERENCES public.person_attribute_type(person_attribute_type_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: person_attribute_value fk_person_attribute_deleted_by; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.person_attribute_value
    ADD CONSTRAINT fk_person_attribute_deleted_by FOREIGN KEY (deleted_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: sp_out_transaction fk_spot_loan; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.sp_out_transaction
    ADD CONSTRAINT fk_spot_loan FOREIGN KEY (loan_id) REFERENCES public.loan(loan_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: sp_out_transaction fk_spot_np; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.sp_out_transaction
    ADD CONSTRAINT fk_spot_np FOREIGN KEY (person_id) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: sp_out_transaction fk_spot_sppo; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.sp_out_transaction
    ADD CONSTRAINT fk_spot_sppo FOREIGN KEY (payment_order_id) REFERENCES public.sp_payment_order(payment_order_id) ON UPDATE CASCADE;


--
-- Name: sp_payment_order fk_sppo_np; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.sp_payment_order
    ADD CONSTRAINT fk_sppo_np FOREIGN KEY (processed_by) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: task_queue fk_tc_loan; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.task_queue
    ADD CONSTRAINT fk_tc_loan FOREIGN KEY (loan_id) REFERENCES public.loan(loan_id) ON UPDATE CASCADE;


--
-- Name: task_queue fk_tc_natural_person; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.task_queue
    ADD CONSTRAINT fk_tc_natural_person FOREIGN KEY (owner_person_id) REFERENCES public.natural_person(person_id) ON UPDATE CASCADE;


--
-- Name: task_queue fk_tc_process_type; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.task_queue
    ADD CONSTRAINT fk_tc_process_type FOREIGN KEY (process_type_id) REFERENCES public.process_type(process_type_id) ON UPDATE CASCADE;


--
-- Name: mail_queue mail_queue_fk0; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.mail_queue
    ADD CONSTRAINT mail_queue_fk0 FOREIGN KEY (created_by) REFERENCES public.natural_person(person_id);


--
-- Name: mail_queue mail_queue_notification_queue; Type: FK CONSTRAINT; Schema: public; Owner: cmdb_user1
--

ALTER TABLE ONLY public.mail_queue
    ADD CONSTRAINT mail_queue_notification_queue FOREIGN KEY (notification_queue_id) REFERENCES public.notification_queue(notification_queue_id) ON UPDATE CASCADE;


--
-- PostgreSQL database dump complete
--

