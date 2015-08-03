--1 up
CREATE TABLE IF NOT EXISTS tenant (
    id                  SERIAL NOT NULL PRIMARY KEY,
    ident               VARCHAR(16) NOT NULL UNIQUE,
    name                VARCHAR(64) NOT NULL
);
CREATE TABLE IF NOT EXISTS tenant_map (
    id                  SERIAL NOT NULL PRIMARY KEY,
    tenant              INTEGER NOT NULL REFERENCES tenant (id) DEFERRABLE INITIALLY DEFERRED,
    hostname            VARCHAR(255) NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS account (
    id                  SERIAL NOT NULL PRIMARY KEY,
    tenant              INTEGER NOT NULL REFERENCES tenant (id) DEFERRABLE INITIALLY DEFERRED,
    email               VARCHAR(255) NOT NULL,
    name                VARCHAR(255) NOT NULL
);
CREATE TABLE IF NOT EXISTS account_json (
    id                  SERIAL NOT NULL PRIMARY KEY,
    account             INTEGER NOT NULL REFERENCES account (id) DEFERRABLE INITIALLY DEFERRED,
    json_data           TEXT NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS auth_nonce (
    id                  SERIAL NOT NULL PRIMARY KEY,
    nonce               VARCHAR(48) NOT NULL UNIQUE
);

--1 down
DROP TABLE account_json;
DROP TABLE account;
DROP TABLE tenant_map;
DROP TABLE tenant;
DROP TABLE auth_nonce;

--2 up
ALTER TABLE auth_nonce ADD used INTEGER NOT NULL DEFAULT 0;

--3 up
INSERT INTO tenant (ident, name) VALUES ('benlocal', 'Ben Local Test');
INSERT INTO tenant_map (tenant, hostname) VALUES (1, 'localhost');

--3 down

--4 up
ALTER TABLE auth_nonce ADD created TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP;

--4 down
