-- Module 7: Synthea sample healthcare data (MySQL 26.7.0)
-- Run only on a NEW/EMPTY database. Never re-run imports into populated tables.
-- Download the public April 2020 sample CSV archive listed in project.md.
-- Extract patients.csv, encounters.csv, and conditions.csv.
-- Update local paths as needed, and connect with mysql --local-infile=1 -u root -p.

CREATE DATABASE IF NOT EXISTS synthea_healthcare;
USE synthea_healthcare;

CREATE TABLE patients (
    Id VARCHAR(36) PRIMARY KEY,
    BIRTHDATE DATE,
    DEATHDATE DATE,
    SSN VARCHAR(20),
    DRIVERS VARCHAR(30),
    PASSPORT VARCHAR(30),
    PREFIX VARCHAR(20),
    FIRST VARCHAR(100),
    LAST VARCHAR(100),
    SUFFIX VARCHAR(20),
    MAIDEN VARCHAR(100),
    MARITAL VARCHAR(10),
    RACE VARCHAR(50),
    ETHNICITY VARCHAR(50),
    GENDER VARCHAR(10),
    BIRTHPLACE VARCHAR(255),
    ADDRESS VARCHAR(255),
    CITY VARCHAR(100),
    STATE VARCHAR(100),
    COUNTY VARCHAR(100),
    ZIP VARCHAR(15),
    LAT DECIMAL(10,7),
    LON DECIMAL(10,7),
    HEALTHCARE_EXPENSES DECIMAL(14,2),
    HEALTHCARE_COVERAGE DECIMAL(14,2)
);

CREATE TABLE encounters (
    Id VARCHAR(36) PRIMARY KEY,
    START DATETIME,
    STOP DATETIME,
    PATIENT VARCHAR(36) NOT NULL,
    ORGANIZATION VARCHAR(36),
    PROVIDER VARCHAR(36),
    PAYER VARCHAR(36),
    ENCOUNTERCLASS VARCHAR(50),
    CODE VARCHAR(50),
    DESCRIPTION VARCHAR(512),
    BASE_ENCOUNTER_COST DECIMAL(16,2),
    TOTAL_CLAIM_COST DECIMAL(16,2),
    PAYER_COVERAGE DECIMAL(16,2),
    REASONCODE VARCHAR(50),
    REASONDESCRIPTION VARCHAR(512),
    FOREIGN KEY (PATIENT) REFERENCES patients(Id)
);

CREATE TABLE conditions (
    condition_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    START DATE,
    STOP DATE,
    PATIENT VARCHAR(36) NOT NULL,
    ENCOUNTER VARCHAR(36) NOT NULL,
    CODE VARCHAR(50),
    DESCRIPTION VARCHAR(512),
    FOREIGN KEY (PATIENT) REFERENCES patients(Id),
    FOREIGN KEY (ENCOUNTER) REFERENCES encounters(Id)
);

-- Requires administrative permissions. Disable again after completing imports.
SET GLOBAL local_infile = ON;

-- Import parent patients before foreign-key-dependent tables.
LOAD DATA LOCAL INFILE '/Users/jameswebb/Downloads/csv/patients.csv'
INTO TABLE patients
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(Id, @birthdate, @deathdate, SSN, DRIVERS, PASSPORT, PREFIX,
 FIRST, LAST, SUFFIX, MAIDEN, MARITAL, RACE, ETHNICITY,
 GENDER, BIRTHPLACE, ADDRESS, CITY, STATE, COUNTY, ZIP,
 @lat, @lon, @expenses, @coverage)
SET
 BIRTHDATE = NULLIF(@birthdate, ''),
 DEATHDATE = NULLIF(@deathdate, ''),
 LAT = NULLIF(@lat, ''),
 LON = NULLIF(@lon, ''),
 HEALTHCARE_EXPENSES = NULLIF(@expenses, ''),
 HEALTHCARE_COVERAGE = NULLIF(TRIM(TRAILING '\r' FROM @coverage), '');
-- Actual import: 1,171 rows; 3,048 notes, first 15 inspected for precision.

LOAD DATA LOCAL INFILE '/Users/jameswebb/Downloads/csv/encounters.csv'
INTO TABLE encounters
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(Id, @start, @stop, PATIENT, ORGANIZATION, PROVIDER,
 PAYER, ENCOUNTERCLASS, CODE, DESCRIPTION,
 @base_cost, @total_cost, @payer_coverage,
 REASONCODE, @reason_description)
SET
 START = CASE
   WHEN TRIM(@start) = '' THEN NULL
   ELSE STR_TO_DATE(LEFT(@start, 19), '%Y-%m-%dT%H:%i:%s')
 END,
 STOP = CASE
   WHEN TRIM(@stop) = '' THEN NULL
   ELSE STR_TO_DATE(LEFT(@stop, 19), '%Y-%m-%dT%H:%i:%s')
 END,
 BASE_ENCOUNTER_COST = CASE
   WHEN TRIM(@base_cost) = '' THEN NULL
   ELSE ROUND(CAST(@base_cost AS DOUBLE), 2)
 END,
 TOTAL_CLAIM_COST = CASE
   WHEN TRIM(@total_cost) = '' THEN NULL
   ELSE ROUND(CAST(@total_cost AS DOUBLE), 2)
 END,
 PAYER_COVERAGE = CASE
   WHEN TRIM(@payer_coverage) = '' THEN NULL
   ELSE ROUND(CAST(@payer_coverage AS DOUBLE), 2)
 END,
 REASONDESCRIPTION = NULLIF(TRIM(TRAILING '\r' FROM @reason_description), '');
-- Actual import: 53,346 rows, 0 warnings.

LOAD DATA LOCAL INFILE '/Users/jameswebb/Downloads/csv/conditions.csv'
INTO TABLE conditions
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@start, @stop, PATIENT, ENCOUNTER, CODE, @description)
SET
 START = NULLIF(@start, ''),
 STOP = NULLIF(@stop, ''),
 DESCRIPTION = NULLIF(TRIM(TRAILING '\r' FROM @description), '');
-- Actual import: 8,376 rows, 0 warnings.

SET GLOBAL local_infile = OFF;

SHOW TABLES;
DESCRIBE patients;
DESCRIBE encounters;
DESCRIBE conditions;

SELECT 'Patients' AS table_name, COUNT(*) AS records FROM patients
UNION ALL SELECT 'Encounters', COUNT(*) FROM encounters
UNION ALL SELECT 'Conditions', COUNT(*) FROM conditions;

SELECT * FROM patients LIMIT 5;
SELECT * FROM encounters LIMIT 5;
SELECT * FROM conditions LIMIT 5;

SELECT COUNT(*) AS total_patients,
       COUNT(DISTINCT Id) AS unique_patients,
       SUM(BIRTHDATE IS NULL) AS missing_birthdates,
       SUM(DEATHDATE IS NULL) AS missing_deathdates,
       SUM(LAT < -90 OR LAT > 90) AS invalid_latitudes,
       SUM(LON < -180 OR LON > 180) AS invalid_longitudes
FROM patients;

SELECT p.GENDER, p.BIRTHDATE, e.ENCOUNTERCLASS,
       e.START AS encounter_date, c.DESCRIPTION AS diagnosis
FROM patients p
JOIN encounters e ON p.Id = e.PATIENT
JOIN conditions c ON e.Id = c.ENCOUNTER AND p.Id = c.PATIENT
LIMIT 10;

SELECT ENCOUNTERCLASS,
       COUNT(*) AS total_encounters,
       ROUND(AVG(TOTAL_CLAIM_COST), 2) AS average_claim_cost
FROM encounters
GROUP BY ENCOUNTERCLASS
ORDER BY total_encounters DESC;

SELECT DESCRIPTION AS medical_condition,
       COUNT(*) AS total_diagnoses,
       COUNT(DISTINCT PATIENT) AS unique_patients
FROM conditions
GROUP BY DESCRIPTION
ORDER BY total_diagnoses DESC
LIMIT 10;
