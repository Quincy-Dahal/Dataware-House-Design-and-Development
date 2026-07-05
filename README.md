# Police Crime Data Warehouse & Analytics Platform

An end-to-end **data warehousing and business-intelligence project** built on a UK police crime dataset. The project covers the full lifecycle: designing a dimensional data mart, building the schema in Oracle, implementing a production-style **ETL pipeline in PL/SQL**, and delivering analytical reports and dashboards across **Oracle APEX, Excel, and Tableau**.

> **Business question:** How effectively are reported crimes being *closed* - by area, by time period, by crime type, and by officer - and what does that reveal about resourcing and performance?

---

## Overview

Police forces record crime data across multiple operational systems, each with its own structure and data-quality issues. This project consolidates three separate source systems into a single, clean, analysis-ready **data mart**, then uses it to answer real performance questions for crime analysts and police managers.

**Core KPI - "Closed Crimes":** measured as `SUM(no_of_crimes)` from the fact table, sliceable by year, month, crime type, location, and officer.

**Source systems integrated:**
- `PRCS` - an operational police system (officers, stations, areas; postcode-level addresses; some missing values)
- `PS_WALES` - a richer system with dedicated location and region tables
- `CRIME_DATA_LEEDS` - supplementary crime data loaded from Excel

---

## Tech Stack

| Layer | Tools & Technologies |
|---|---|
| **Database** | Oracle Database |
| **ETL / Data Integration** | PL/SQL - packages, procedures, sequences, triggers |
| **Data Modelling** | Star schema (Kimball dimensional modelling), QSEE for schema design |
| **BI & Reporting** | Oracle APEX, Microsoft Excel (PivotTables, dashboards), Tableau |
| **Concepts applied** | OLTP vs OLAP, data warehouse vs data mart, Inmon vs Kimball, SCD, OLAP operations (roll-up, drill-down, slice, dice, pivot) |

---

## Data Warehouse Architecture

The data mart uses a **star schema** - one central fact table surrounded by four dimension tables, each in a 1:M relationship with the fact.

```
                    ┌──────────────┐
                    │   DIM_TIME   │
                    │ year, month, │
                    │     day      │
                    └──────┬───────┘
                           │
   ┌──────────────┐   ┌────┴─────────────────┐   ┌────────────────┐
   │ DIM_LOCATION │   │  FACT_CLOSED_CRIME   │   │ DIM_CRIME_TYPE │
   │ region, city,│───│  crime_key (PK)      │───│ crime_type,    │
   │ postcode,    │   │  no_of_crimes        │   │ closure_status │
   │ street       │   │  time_id, location_id│   └────────────────┘
   └──────────────┘   │  crimetype_id,       │
                      │  officer_id (FKs)    │
                      └──────────┬───────────┘
                           ┌─────┴────────┐
                           │ DIM_OFFICER  │
                           │ full_name,   │
                           │ department,  │
                           │    rank      │
                           └──────────────┘
```

**Fact table - `FACT_CLOSED_CRIME`**
- **Measure:** `no_of_crimes`
- **Primary key:** `crime_key`
- **Foreign keys:** `time_id`, `location_id`, `crimetype_id`, `officer_id`

**Dimension tables**
- `DIM_TIME` - time_id, year, month, day
- `DIM_LOCATION` - location_id, region_name, city_name, street_name, post_code
- `DIM_CRIME_TYPE` - crimetype_id, crime_type, closure_status
- `DIM_OFFICER` - officer_id, full_name, department, rank

---

## ETL Pipeline (PL/SQL)

A full **Extract → Transform → Load** pipeline built with reusable PL/SQL packages and procedures, with logging and data-quality handling at every stage.

**1. Error & Process Logging**
- Dedicated log tables with sequences and triggers to auto-generate unique IDs
- Every ETL step writes process and error records for traceability

**2. Staging (Extract)**
- Raw data pulled from all three source systems into staging tables
- Packaged procedures for each entity (location, officer, crime type, crime register)

**3. Transformation (Clean & Validate)**
- **Bad-data identification** - records with errors, missing values, or inconsistencies are routed to dedicated bad-data tables
- **Good-data identification** - validated records promoted for loading
- **Audit tables** with triggers track changes to location and officer data
- Data type/format standardisation before loading

**4. Loading**
- Clean data loaded into the four dimensions, then into the fact table
- Load procedures per dimension (`DIM_LOCATION`, `DIM_OFFICER`, `DIM_CRIME_TYPE`, `DIM_TIME`)
- Fact table populated only from trusted, validated data

> The result is a consistent, reliable data mart where only clean, validated records reach the reporting layer.

---

## Analytics & Reporting

Fifteen analytical reports plus dashboards were delivered across three BI tools, each demonstrating a different reporting stack.

### Oracle APEX
- Crime closure rate by crime type
- Annual crime breakdown by case status
- Top city by closed crimes per year
- Quantitative analysis of closed crimes by city
- Progression of closed crimes by month
- Consolidated **Oracle dashboard**

### Microsoft Excel
- Performance by city and officer (with **drill-down** analysis)
- Top solvers by area (2018)
- Crime type analysis - closure status vs total crimes
- Closed crimes by post code
- Crime volume and closure status over time
- Consolidated **Excel dashboard**

### Tableau
- Officer crime closure rate (Leeds, PRCS, PS_WALES)
- Closed crimes per city (2017)
- Crime type performance (2018)
- Police crime type performance (2015)
- Individual officer performance analysis (2017)
- Consolidated **Tableau dashboard**

---

## Analytical Reports Supported by the Data Mart

The schema was designed to answer five core business questions:

1. **Closed crimes in a particular area** - resolution volume by region
2. **Closed crimes per year** - annual resolution trends
3. **Duration to close crimes by crime type** - efficiency by category
4. **Progression of closed crimes by month** - month-over-month movement
5. **Trends in officer performance over time** - individual performance tracking

---

## Repository Contents

| Artefact | Description |
|---|---|
| `SS_DDL.sql` | Star schema DDL - sequences, triggers, tables, and foreign-key references |
| `Data_Integration.sql` | Data integration / pivoting logic and source-system consolidation |
| `ETL.sql` | Full ETL implementation - extraction (staging), transformation (bad/good data), and loading |
| Report - *Data Warehousing & ETL* | Design rationale, star-schema modelling, and end-to-end pipeline documentation |
| Report - *Data Analytics* | OLAP operations plus APEX, Excel, and Tableau reports and dashboards |
| Report - *PL/SQL Techniques* | Packages, procedures, triggers, sequences, and audit/logging implementation |

---

## Skills Demonstrated

- **Dimensional data modelling** - star schema design following Kimball methodology
- **PL/SQL development** - packages, procedures, sequences, triggers, and audit logic
- **ETL engineering** - multi-source extraction, data-quality validation (bad vs good data), and staged loading
- **Data integration** - consolidating three heterogeneous source systems into one clean data mart
- **Business intelligence** - building reports and dashboards in Oracle APEX, Excel, and Tableau
- **OLAP analysis** - roll-up, drill-down, slice, dice, and pivot operations
- **Technical documentation** - clear, structured writeups of design decisions and implementation

---
