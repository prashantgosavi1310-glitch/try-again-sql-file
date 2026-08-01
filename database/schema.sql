-- =====================================================================
-- MessMate — PostgreSQL Schema
-- Run this once against a fresh database (or via `npm run migrate`).
-- Safe to re-run: every statement is guarded with IF NOT EXISTS.
--
-- Verified against the live backend (auth.controller.js, user.controller.js,
-- mess.controller.js, otp.service.js) on 2026-08-01 — every table/column
-- referenced by a query in the codebase is present below. No tables were
-- missing from the original file's *content*; if you're seeing
-- "relation ... does not exist", the most likely cause is that this file
-- was updated after the last successful `npm run migrate` run on Railway.
-- Re-run the migration (see bottom of this file) to fix it.
--
-- This version wraps the whole script in an explicit transaction so a
-- failure partway through rolls back cleanly instead of leaving some
-- tables created and others missing.
-- =====================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gives us gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS citext;   -- gives us case-insensitive email columns

-- ---------------------------------------------------------------------
-- users  — student / mess-user accounts (POST /api/user/register)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name        VARCHAR(120)  NOT NULL,
  college_name     VARCHAR(160)  NOT NULL,
  roll_number      VARCHAR(60)   NOT NULL,
  mobile           VARCHAR(10)   NOT NULL UNIQUE,
  email            CITEXT        NOT NULL UNIQUE,
  password_hash    TEXT          NOT NULL,
  user_photo_path  TEXT,
  college_id_path  TEXT,
  email_verified   BOOLEAN       NOT NULL DEFAULT FALSE,
  is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- messes — mess-owner accounts + their mess listing (POST /api/mess/register)
-- Owner identity and mess details live in one row by design: the
-- registration form collects both together and there is a strict 1:1
-- relationship between an owner login and their mess listing.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS messes (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- owner / account fields
  owner_name          VARCHAR(120)  NOT NULL,
  mobile              VARCHAR(10)   NOT NULL UNIQUE,
  email               CITEXT        NOT NULL UNIQUE,
  password_hash       TEXT          NOT NULL,
  owner_photo_path    TEXT,

  -- mess listing fields
  mess_name           VARCHAR(160)  NOT NULL,
  address             VARCHAR(255)  NOT NULL,
  city                VARCHAR(100)  NOT NULL,
  pincode             VARCHAR(10)   NOT NULL,
  map_link            TEXT,
  veg_type            VARCHAR(10)   NOT NULL DEFAULT 'veg'
                        CHECK (veg_type IN ('veg', 'nonveg', 'both')),
  meals               TEXT[]        NOT NULL DEFAULT '{}',
  monthly_fees        NUMERIC(10,2) NOT NULL CHECK (monthly_fees >= 0),
  daily_food_price    NUMERIC(10,2)          CHECK (daily_food_price >= 0),
  security_deposit    NUMERIC(10,2)          CHECK (security_deposit >= 0),
  capacity            INTEGER       NOT NULL CHECK (capacity >= 1),
  available_seats     INTEGER       NOT NULL CHECK (available_seats >= 0),
  kitchen_photo_path  TEXT,
  dining_photo_path   TEXT,

  email_verified      BOOLEAN       NOT NULL DEFAULT FALSE,
  is_active           BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),

  CONSTRAINT seats_within_capacity CHECK (available_seats <= capacity)
);

-- ---------------------------------------------------------------------
-- mess_photos — multiple gallery photos per mess (messPhotos[] upload)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mess_photos (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mess_id     UUID NOT NULL REFERENCES messes(id) ON DELETE CASCADE,
  photo_path  TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- weekly_menu — one row per (mess, day) — matches the frontend's
-- menu-<day>-<meal> text inputs
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS weekly_menu (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mess_id     UUID NOT NULL REFERENCES messes(id) ON DELETE CASCADE,
  day_of_week VARCHAR(10) NOT NULL
                CHECK (day_of_week IN
                  ('monday','tuesday','wednesday','thursday','friday','saturday','sunday')),
  breakfast   VARCHAR(255),
  lunch       VARCHAR(255),
  dinner      VARCHAR(255),
  UNIQUE (mess_id, day_of_week)
);

-- ---------------------------------------------------------------------
-- otp_verifications — one row per OTP send; verified/expired rows are
-- left for audit but a background job (or the next request) may prune
-- them. The OTP itself is stored only as a bcrypt hash.
--
-- Columns confirmed against services/otp.service.js:
--   createOtp()        -> INSERT (email, otp_hash, expires_at)
--   verifyOtp()         -> SELECT id, otp_hash, attempts, expires_at ... WHERE verified = FALSE
--   verifyOtp() fail    -> UPDATE attempts = attempts + 1
--   verifyOtp() success -> UPDATE verified = TRUE, verified_at = now()
--   consumeVerifiedOtp() -> SELECT ... WHERE verified = TRUE AND verified_at > now() - interval
--   countRecentRequests() -> SELECT COUNT(*) ... WHERE created_at > now() - interval
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS otp_verifications (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         CITEXT      NOT NULL,
  otp_hash      TEXT        NOT NULL,
  purpose       VARCHAR(30) NOT NULL DEFAULT 'registration',
  attempts      INTEGER     NOT NULL DEFAULT 0,
  verified      BOOLEAN     NOT NULL DEFAULT FALSE,
  verified_at   TIMESTAMPTZ,
  expires_at    TIMESTAMPTZ NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- refresh_tokens — optional, supports refresh-token rotation if you
-- extend the frontend to use it later. Stores only a hash of the token.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_type  VARCHAR(10) NOT NULL CHECK (account_type IN ('user', 'mess', 'admin')),
  account_id    UUID        NOT NULL,
  token_hash    TEXT        NOT NULL,
  revoked       BOOLEAN     NOT NULL DEFAULT FALSE,
  expires_at    TIMESTAMPTZ NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- admins — minimal table backing the authorizeAdmin middleware and
-- auth.controller.js's login() fallback lookup (id, full_name, email,
-- password_hash all confirmed referenced there)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admins (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name      VARCHAR(120) NOT NULL,
  email          CITEXT       NOT NULL UNIQUE,
  password_hash  TEXT         NOT NULL,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_users_email            ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_mobile            ON users (mobile);

CREATE INDEX IF NOT EXISTS idx_messes_email            ON messes (email);
CREATE INDEX IF NOT EXISTS idx_messes_mobile           ON messes (mobile);
CREATE INDEX IF NOT EXISTS idx_messes_city             ON messes (city);
CREATE INDEX IF NOT EXISTS idx_messes_pincode          ON messes (pincode);

CREATE INDEX IF NOT EXISTS idx_mess_photos_mess_id     ON mess_photos (mess_id);
CREATE INDEX IF NOT EXISTS idx_weekly_menu_mess_id     ON weekly_menu (mess_id);

CREATE INDEX IF NOT EXISTS idx_otp_email               ON otp_verifications (email);
CREATE INDEX IF NOT EXISTS idx_otp_email_created       ON otp_verifications (email, created_at);
CREATE INDEX IF NOT EXISTS idx_otp_verified_lookup     ON otp_verifications (email, verified, verified_at);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_account  ON refresh_tokens (account_type, account_id);

-- ---------------------------------------------------------------------
-- updated_at auto-touch triggers
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_messes_updated_at ON messes;
CREATE TRIGGER trg_messes_updated_at
  BEFORE UPDATE ON messes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;

-- =====================================================================
-- To apply this on Railway:
--   Railway dashboard -> your service -> Run Command:  npm run migrate
--   or locally:  DATABASE_URL="<railway-postgres-url>" npm run migrate
-- =====================================================================
