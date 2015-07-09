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
    id                  SERIAL NOT NULL PRIMARY KEY
    tenant              INTEGER NOT NULL REFERENCES tenant (id) DEFERRABLE INITIALLY DEFERRED,
    last_auth_from      CHAR(2) NOT NULL DEFAULT '--',
    last_auth_time      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIME,
);
CREATE TABLE IF NOT EXISTS account_json (
    id                  SERIAL NOT NULL PRIMARY KEY,
    account             INTEGER NOT NULL REFERENCES account (id) DEFERRABLE INITIALLY DEFERRED,
    json_data           TEXT NOT NULL DEFAULT '{}'
);

--1 down
DROP TABLE account_json;
DROP TABLE account;
DROP TABLE tenant_map;
DROP TABLE tenant;
