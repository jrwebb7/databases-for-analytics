# Module 7 Database Project: Synthetic Healthcare Records

**Student:** James Webb  
**Course:** Databases for Analytics — Module 7  
**Operating system:** macOS (Apple Silicon)  
**Database system:** MySQL Community Server 26.7.0  
**Database name:** `synthea_healthcare`  
**Project date:** October 8, 2026

## 1. Overview and project purpose

For this exercise, I built a relational MySQL database using publicly available **synthetic** healthcare records generated with MITRE's Synthea project. My goal was to combine patient demographics, clinical encounters, and medical conditions so I could investigate encounter patterns, frequently recorded diagnoses, and healthcare charges using SQL.

The data represents **fictional patients**, not real medical records. It should not be treated as a statistically representative sample of real patients or as evidence of actual clinical costs or disease prevalence.

## 2. Original data source and format

- **Producer:** [Synthea (MITRE)](https://synthetichealth.github.io/synthea/)
- **Public downloads page:** [Synthea downloads](https://synthetichealth.github.io/downloads.html)
- **Specific sample:** [April 2020 sample CSV ZIP](https://synthetichealth.github.io/synthea-sample-data/downloads/synthea_sample_data_csv_apr2020.zip)
- **Official reference for field meanings:** [Synthea CSV File Data Dictionary](https://github.com/synthetichealth/synthea/wiki/CSV-File-Data-Dictionary)
- **Local format:** Three `.csv` files extracted from a ZIP archive. Each file has a header row and comma-delimited records.

I selected three related files from the sample archive. Counts and headers below were measured locally with Python's `csv` module **before importing the files into MySQL**.

| Source CSV | Data represented | Original data rows (excluding header) | Original columns |
|---|---|---:|---:|
| `patients.csv` | Patient demographics and lifetime financial figures | 1,171 | 25 |
| `encounters.csv` | Visits, dates, encounter categories, and costs | 53,346 | 15 |
| `conditions.csv` | Diagnoses and their patient/encounter links | 8,376 | 6 |
| **Total** | | **62,893** | **46 source attributes across the three files** |

This meets the assignment's minimum of three tables: one with at least 1,000 rows and two others with at least 100 rows. The completed database contains 47 columns because I added a generated primary key to `conditions`.

**Initial exploration command (run from the extracted CSV directory):**

```bash
python3 - <<'PY'
import csv
for name in ['patients.csv', 'encounters.csv', 'conditions.csv']:
    with open(name, newline='', encoding='utf-8-sig') as file:
        reader = csv.reader(file)
        columns = next(reader)
        count = sum(1 for _ in reader)
    print(f'{name}: {count:,} rows, {len(columns)} columns')
    print('Columns:', ', '.join(columns))
PY
```

## 3. Relational database design

I used `patients` as the parent table. Every encounter refers to a patient, and every condition refers to both a patient and an encounter. Primary/foreign keys help prevent orphan records.

```text
patients.Id [PRIMARY KEY]
   |                  +--- conditions.PATIENT [FOREIGN KEY]
   +--- encounters.PATIENT [FOREIGN KEY]
             |
             +--- conditions.ENCOUNTER [FOREIGN KEY -> encounters.Id]

encounters.Id [PRIMARY KEY]
conditions.condition_id [AUTO_INCREMENT PRIMARY KEY]
```

The `conditions.csv` source file has no standalone record ID, so I added an auto-incrementing `condition_id` field. Other reference IDs in `encounters` (such as `PAYER` and `PROVIDER`) were preserved as text but were not modeled as foreign keys because their corresponding source tables were outside the three-table scope of this project.

**MySQL types used:** `VARCHAR` for text and UUID identifiers; `DATE` for birth, death, and diagnosis dates; `DATETIME` for clinical visit timestamps; `DECIMAL` for financial values and coordinates; and `BIGINT AUTO_INCREMENT` for the generated condition ID.

## 4. Data dictionary

The column list and types below describe **my imported database**, not the current Synthea exporter schema, which can differ by dataset version. Definitions are informed by the [official Synthea dictionary](https://github.com/synthetichealth/synthea/wiki/CSV-File-Data-Dictionary) and the observed April 2020 CSV headers.

### `patients` — 25 MySQL columns

| Column | MySQL data type | Meaning |
|---|---|---|
| `Id` | `VARCHAR(36)` | Primary key: unique synthetic patient UUID |
| `BIRTHDATE` | `DATE` | Date of birth |
| `DEATHDATE` | `DATE` | Date of death; NULL when not recorded |
| `SSN` | `VARCHAR(20)` | Synthetic Social Security identifier |
| `DRIVERS` | `VARCHAR(30)` | Driver license identifier, when supplied |
| `PASSPORT` | `VARCHAR(30)` | Passport identifier, when supplied |
| `PREFIX` | `VARCHAR(20)` | Name prefix, such as Mr. or Mrs. |
| `FIRST` | `VARCHAR(100)` | First name |
| `LAST` | `VARCHAR(100)` | Family or last name |
| `SUFFIX` | `VARCHAR(20)` | Name suffix, when supplied |
| `MAIDEN` | `VARCHAR(100)` | Maiden name, when supplied |
| `MARITAL` | `VARCHAR(10)` | Marital status code |
| `RACE` | `VARCHAR(50)` | Simulated race category |
| `ETHNICITY` | `VARCHAR(50)` | Simulated ethnicity category |
| `GENDER` | `VARCHAR(10)` | Gender recorded by the generator |
| `BIRTHPLACE` | `VARCHAR(255)` | Birthplace |
| `ADDRESS` | `VARCHAR(255)` | Street address |
| `CITY` | `VARCHAR(100)` | City of residence |
| `STATE` | `VARCHAR(100)` | State of residence |
| `COUNTY` | `VARCHAR(100)` | County of residence |
| `ZIP` | `VARCHAR(15)` | Postal code; stored as text to preserve leading zeros |
| `LAT` | `DECIMAL(10,7)` | Latitude of address |
| `LON` | `DECIMAL(10,7)` | Longitude of address |
| `HEALTHCARE_EXPENSES` | `DECIMAL(14,2)` | Simulated lifetime out-of-pocket healthcare expenses |
| `HEALTHCARE_COVERAGE` | `DECIMAL(14,2)` | Simulated lifetime costs covered by payer(s) |

### `encounters` — 15 MySQL columns

| Column | MySQL data type | Meaning |
|---|---|---|
| `Id` | `VARCHAR(36)` | Primary key: unique synthetic encounter UUID |
| `START` | `DATETIME` | Encounter start timestamp, stored as UTC clock time |
| `STOP` | `DATETIME` | Encounter end timestamp, stored as UTC clock time |
| `PATIENT` | `VARCHAR(36)` | Foreign key to patients.Id |
| `ORGANIZATION` | `VARCHAR(36)` | Organization UUID (corresponding organization table not imported) |
| `PROVIDER` | `VARCHAR(36)` | Provider UUID (provider table not imported) |
| `PAYER` | `VARCHAR(36)` | Payer UUID (payer table not imported) |
| `ENCOUNTERCLASS` | `VARCHAR(50)` | Encounter category, such as wellness or ambulatory |
| `CODE` | `VARCHAR(50)` | Clinical encounter code |
| `DESCRIPTION` | `VARCHAR(512)` | Text description of the encounter |
| `BASE_ENCOUNTER_COST` | `DECIMAL(16,2)` | Base encounter charge, excluding additional line items |
| `TOTAL_CLAIM_COST` | `DECIMAL(16,2)` | Total claim cost for the encounter |
| `PAYER_COVERAGE` | `DECIMAL(16,2)` | Amount covered by payer for the encounter |
| `REASONCODE` | `VARCHAR(50)` | Code for clinical reason for encounter, if supplied |
| `REASONDESCRIPTION` | `VARCHAR(512)` | Text description of reason for encounter |

### `conditions` — 7 MySQL columns

| Column | MySQL data type | Meaning |
|---|---|---|
| `condition_id` | `BIGINT AUTO_INCREMENT` | Added primary key; not in source CSV |
| `START` | `DATE` | Date the diagnosis was recorded |
| `STOP` | `DATE` | Date diagnosis was resolved, if recorded |
| `PATIENT` | `VARCHAR(36)` | Foreign key to patients.Id |
| `ENCOUNTER` | `VARCHAR(36)` | Foreign key to encounters.Id |
| `CODE` | `VARCHAR(50)` | Diagnosis terminology code |
| `DESCRIPTION` | `VARCHAR(512)` | Plain-language description of the diagnosis |

## 5. Import method and transformations

I installed and ran MySQL on macOS and created the `synthea_healthcare` database using `CREATE DATABASE`, `USE`, and three `CREATE TABLE` statements. I validated each table using `SHOW TABLES` and `DESCRIBE`.

I used the MySQL command-line client with `--local-infile=1` and temporarily enabled the `local_infile` server setting, then ran `LOAD DATA LOCAL INFILE`. I imported in dependency order: **patients → encounters → conditions**, so foreign-key references would resolve. I skipped each CSV's header with `IGNORE 1 LINES`.

Key cleaning and type transformations:

1. **Column-name case:** My initial Python inspection produced `KeyError: 'ID'` because the actual header is `Id`. I corrected the script to match the exact header capitalization.
2. **Missing dates:** Empty `DEATHDATE` and condition `STOP` values were converted to SQL `NULL` using `NULLIF`.
3. **Datetime parsing:** An encounter string like `2010-01-23T17:45:28Z` was converted with `STR_TO_DATE(LEFT(...,19), '%Y-%m-%dT%H:%i:%s')`. The source timestamps use UTC; the resulting MySQL `DATETIME` values retain the UTC clock times but do not themselves carry a timezone designation.
4. **Monetary precision:** Currency values were stored in fixed-point `DECIMAL(...,2)` fields. The encounters import also applied `ROUND(...,2)`.
5. **Geographic precision:** Latitude and longitude were stored as `DECIMAL(10,7)`.
6. **End-of-line cleanup:** `TRIM(TRAILING '\r' FROM ...)` handled potential carriage-return characters in the last CSV column.
7. **Synthetic IDs:** UUID identifiers were preserved in `VARCHAR(36)` columns, enabling joins and foreign keys.

**Import warnings and investigation:** The `patients` import loaded all 1,171 records but reported **3,048 diagnostic messages**. I reproduced the load in a temporary table and inspected the first 15 with `SHOW WARNINGS LIMIT 15`; the displayed messages were code 1265 (`Data truncated`) for `LAT`, `LON`, and `HEALTHCARE_COVERAGE`. These are consistent with values carrying more decimal places than the selected destination columns. I kept the fixed-point types appropriate to the analysis. **Only the first 15 messages were inspected, so I do not claim that every one of the 3,048 messages has been independently verified.** The encounters and conditions imports reported zero warnings and zero skipped rows.

The full recorded table-creation, import, and analysis commands are available in [`synthea_project_queries.sql`](./synthea_project_queries.sql). For reproducibility, the SQL file is designed for a **new empty database**, with file paths edited to match the local extraction folder.

## 6. Table verification

I used these commands to show database structure and sample records:

```sql
SHOW TABLES;
DESCRIBE patients;
DESCRIBE encounters;
DESCRIBE conditions;

SELECT * FROM patients LIMIT 5;
SELECT * FROM encounters LIMIT 5;
SELECT * FROM conditions LIMIT 5;
```

`SELECT *` demonstrates access to **every column** in each table, while `LIMIT 5` keeps the printed results readable.

**Actual imported row counts** (verified in MySQL):

| Database table | Expected CSV rows | Actual MySQL rows | Skipped on import | Import warnings/notes |
|---|---:|---:|---:|---:|
| `patients` | 1,171 | 1,171 | 0 | 3,048 (investigated; see above) |
| `encounters` | 53,346 | 53,346 | 0 | 0 |
| `conditions` | 8,376 | 8,376 | 0 | 0 |
| **Total** | **62,893** | **62,893** | **0** | |

**Patient data-quality check:**

```sql
SELECT COUNT(*) AS total_patients,
       COUNT(DISTINCT Id) AS unique_patients,
       SUM(BIRTHDATE IS NULL) AS missing_birthdates,
       SUM(DEATHDATE IS NULL) AS missing_deathdates,
       SUM(LAT < -90 OR LAT > 90) AS invalid_latitudes,
       SUM(LON < -180 OR LON > 180) AS invalid_longitudes
FROM patients;
```

| Total patients | Unique patient IDs | Missing birth dates | Missing death dates | Invalid latitudes | Invalid longitudes |
|---:|---:|---:|---:|---:|---:|
| 1,171 | 1,171 | 0 | 1,000 | 0 | 0 |

The missing death dates are stored as `NULL`, not the text string `"NULL"`. The geographic validation checks the ranges for non-NULL values; it is not a full source-to-destination cell-by-cell audit.

**Evidence screenshots to add before submission:** Add authentic screenshots from your own MySQL session to an `exercises/screenshots/` folder showing `SHOW TABLES`/`DESCRIBE`, the three `SELECT *` results, and the analysis results. Include at least one real screenshot with the numbered Canvas submission. Do not replace these with generated screenshots.

## 7. SQL analysis: joins and aggregations

### Query A — Three-table join: patient, encounter, and diagnosis

This query links records by foreign keys, returning patient demographics, clinical visit category and timestamp, and diagnosis:

```sql
SELECT p.GENDER, p.BIRTHDATE, e.ENCOUNTERCLASS,
       e.START AS encounter_date, c.DESCRIPTION AS diagnosis
FROM patients p
JOIN encounters e ON p.Id = e.PATIENT
JOIN conditions c
  ON e.Id = c.ENCOUNTER
 AND p.Id = c.PATIENT
LIMIT 10;
```

**Selected rows from my results:**

| Gender | Birth date | Encounter category | Encounter start (UTC) | Diagnosis |
|---|---|---|---|---|
| M | 2003-11-18 | ambulatory | 2012-08-03 15:06:37 | Acute viral pharyngitis (disorder) |
| M | 2003-11-18 | ambulatory | 2012-10-14 15:06:37 | Streptococcal sore throat (disorder) |
| M | 2003-11-18 | inpatient | 2017-12-21 15:06:37 | Chronic pain |
| M | 2009-11-26 | outpatient | 2012-04-14 23:31:38 | Otitis media |

This shows that visit records and diagnoses can be meaningfully connected through both patient and encounter IDs.

### Query B — Encounter volume and average claim costs (`GROUP BY` + `COUNT` + `AVG`)

```sql
SELECT ENCOUNTERCLASS,
       COUNT(*) AS total_encounters,
       ROUND(AVG(TOTAL_CLAIM_COST), 2) AS average_claim_cost
FROM encounters
GROUP BY ENCOUNTERCLASS
ORDER BY total_encounters DESC;
```

**Actual query output:**

| Encounter class | Number of encounters | Average claim cost |
|---|---:|---:|
| wellness | 19,106 | $129.16 |
| ambulatory | 18,936 | $129.16 |
| outpatient | 9,003 | $129.16 |
| urgentcare | 2,373 | $129.16 |
| emergency | 2,090 | $129.16 |
| inpatient | 1,838 | $117.27 |

### Query C — Ten most frequently recorded diagnoses (`GROUP BY` + `COUNT DISTINCT`)

```sql
SELECT DESCRIPTION AS medical_condition,
       COUNT(*) AS total_diagnoses,
       COUNT(DISTINCT PATIENT) AS unique_patients
FROM conditions
GROUP BY DESCRIPTION
ORDER BY total_diagnoses DESC
LIMIT 10;
```

**Actual query output:**

| Condition | Diagnosis records | Distinct patients |
|---|---:|---:|
| Viral sinusitis (disorder) | 1,248 | 743 |
| Acute viral pharyngitis (disorder) | 653 | 492 |
| Acute bronchitis (disorder) | 563 | 464 |
| Normal pregnancy | 516 | 205 |
| Body mass index 30+ - obesity (finding) | 449 | 449 |
| Prediabetes | 317 | 317 |
| Hypertension | 302 | 302 |
| Anemia (disorder) | 300 | 300 |
| Chronic sinusitis (disorder) | 236 | 233 |
| Miscarriage in first trimester | 221 | 221 |

## 8. Insights and interpretation

1. **Most encounters were classified as wellness or ambulatory.** The query returned 19,106 wellness and 18,936 ambulatory visits, substantially more than inpatient or emergency encounters.
2. **Recording frequency is not patient prevalence.** Viral sinusitis appeared in 1,248 diagnosis records, but only 743 distinct patients. The difference illustrates why joins, grouping, and distinct counts matter in health data analysis.
3. **Costs in this sample are largely standardized by the simulator.** Five encounter classes had the same mean claim amount ($129.16); inpatient encounters averaged $117.27. These figures should not be interpreted as real-world prices or costs by care setting.
4. **Record-level validation matters beyond row counts.** Patient records matched the original count, but import diagnostics still identified reduced numerical precision, motivating a check of data types and stored values.

## 9. Challenges and reflection

The main obstacles were restoring access to my local MySQL installation after forgetting the `root` password, handling case-sensitive field names during Python inspection, converting blank values and ISO 8601 timestamps, and evaluating numeric-precision messages produced during CSV import. I addressed these one at a time by verifying the MySQL service, recovering access, inspecting the raw CSV headers, applying SQL transformations during `LOAD DATA LOCAL INFILE`, and comparing source and imported row counts.

This project reinforced the importance of inspecting data **before** importing it, creating relational links deliberately, and validating the result with more than a successful `CREATE TABLE` message. It also gave me practical experience using aggregate SQL queries to identify patterns in healthcare data.

## 10. Reproduction and submission checklist

- [x] Download and inspect a public, unprotected healthcare dataset.
- [x] Create at least three tables with the required minimum row counts.
- [x] Use date, numeric, and string SQL data types.
- [x] Import the CSV data, retaining all original rows.
- [x] Document table structures and the full data dictionary.
- [x] Run `SELECT *` on each table, demonstrate a join, and run aggregate queries.
- [x] Summarize challenges, solutions, and insights.
- [ ] Add authentic MySQL screenshots to this public GitHub folder and embed or link them here.
- [ ] Confirm this report and screenshots load **without GitHub login** in a private/incognito browser window.
- [ ] Paste the public GitHub file link and verification screenshot into the Canvas success questions.

## References

- [Synthea, official project](https://synthetichealth.github.io/synthea/)
- [Official Synthea CSV file data dictionary](https://github.com/synthetichealth/synthea/wiki/CSV-File-Data-Dictionary)
- [Synthea sample data downloads](https://synthetichealth.github.io/downloads.html)
- Walonoski J. et al., [*Synthea: An approach, method, and software mechanism for generating synthetic patients and the synthetic electronic health care record*](https://doi.org/10.1093/jamia/ocx079), JAMIA (2018).