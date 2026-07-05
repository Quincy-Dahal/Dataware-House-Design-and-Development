--------------------------------------------------------------
-- 1. DROP EXISTING SEQUENCES 
--------------------------------------------------------------
DROP SEQUENCE stg_location_seq;
DROP SEQUENCE stg_crime_type_seq;
DROP SEQUENCE stg_officer_seq;
DROP SEQUENCE stg_crime_register_seq;


--------------------------------------------------------------
-- 2. DROP EXISTING TRIGGERS
--------------------------------------------------------------
DROP TRIGGER stg_location_trig;
DROP TRIGGER stg_crime_type_trig;
DROP TRIGGER stg_officer_trig;
DROP TRIGGER stg_crime_register_trig;


--------------------------------------------------------------
-- 3. DROP EXISTING TABLES
--------------------------------------------------------------
DROP TABLE stg_crime_register;
DROP TABLE stg_officer;
DROP TABLE stg_crime_type;
DROP TABLE stg_location;


--------------------------------------------------------------
-- 4. CREATE SEQUENCES
--------------------------------------------------------------
CREATE SEQUENCE stg_location_seq
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

CREATE SEQUENCE stg_crime_type_seq
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

CREATE SEQUENCE stg_officer_seq
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

CREATE SEQUENCE stg_crime_register_seq
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;


--------------------------------------------------------------
-- 5. CREATE STAGING TABLES
--------------------------------------------------------------

-- Staging table for location data.
CREATE TABLE stg_location(
    location_id      INTEGER NOT NULL,
    location_key     INTEGER,          -- Original key from source
    region_name      VARCHAR(20),
    street_name      VARCHAR(20),
    post_code        VARCHAR(20),
    city_name        VARCHAR(20),
    data_source      VARCHAR(40),      -- Indicates PRCS or PS_WALES
    PRIMARY KEY (location_id)
);

-- Staging table for crime type data.
CREATE TABLE stg_crime_type(
    crimetype_id     INTEGER NOT NULL,
    crime_type_key   INTEGER,          -- Original crime type ID
    closure_status   VARCHAR(20),
    crime_type       VARCHAR(20),
    fk_location      INTEGER,         
    data_source      VARCHAR(40),
    PRIMARY KEY (crimetype_id)
);

-- Staging table for officer data.
CREATE TABLE stg_officer(
    officer_id       INTEGER NOT NULL,
    officer_key      INTEGER,          -- Employee ID or Officer ID from source
    full_name        VARCHAR(100),
    department       VARCHAR(20),
    rank             VARCHAR(20),
    fk_location      INTEGER,          -- Area/Location key
    data_source      VARCHAR(40),
    PRIMARY KEY (officer_id)
);

-- Staging table for crime register / fact data.
CREATE TABLE stg_crime_register(
    crime_register_id  INTEGER NOT NULL,
    fk_location        INTEGER,
    fk_police_officer  INTEGER,
    fk_crime_type      INTEGER,
    closed_date        VARCHAR(10),
    data_source        VARCHAR(40),
    PRIMARY KEY (crime_register_id)
);


--------------------------------------------------------------
-- 6. CREATE TRIGGERS FOR SURROGATE KEYS
--------------------------------------------------------------

-- Trigger: Location
CREATE OR REPLACE TRIGGER stg_location_trig
BEFORE INSERT ON stg_location
FOR EACH ROW
BEGIN
    IF :new.location_id IS NULL THEN
        SELECT stg_location_seq.NEXTVAL
        INTO :new.location_id FROM SYS.DUAL;
    END IF;
END;
/

-- Trigger: Crime Type
CREATE OR REPLACE TRIGGER stg_crime_type_trig
BEFORE INSERT ON stg_crime_type
FOR EACH ROW
BEGIN
    IF :new.crimetype_id IS NULL THEN
        SELECT stg_crime_type_seq.NEXTVAL
        INTO :new.crimetype_id FROM SYS.DUAL;
    END IF;
END;
/

-- Trigger: Officer
CREATE OR REPLACE TRIGGER stg_officer_trig
BEFORE INSERT ON stg_officer
FOR EACH ROW
BEGIN
    IF :new.officer_id IS NULL THEN
        SELECT stg_officer_seq.NEXTVAL
        INTO :new.officer_id FROM SYS.DUAL;
    END IF;
END;
/

-- Trigger: Crime Register
CREATE OR REPLACE TRIGGER stg_crime_register_trig
BEFORE INSERT ON stg_crime_register
FOR EACH ROW
BEGIN
    IF :new.crime_register_id IS NULL THEN
        SELECT stg_crime_register_seq.NEXTVAL
        INTO :new.crime_register_id FROM SYS.DUAL;
    END IF;
END;
/

--------------------------------------------------------------
-- PACKAGE: PKG_STG_LOAD  (for staging procedures)
--------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_stg_load AS
    PROCEDURE process_stg_location;
    PROCEDURE process_stg_officer;
    PROCEDURE process_stg_crime_type;
    PROCEDURE process_stg_crime_register;
END pkg_stg_load;
/
--------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY pkg_stg_load AS

 ----------------------------------------------------------
    -- Private Function: Log process execution
 ----------------------------------------------------------
    FUNCTION log_process_func (
        p_process_name   IN VARCHAR2,
        p_target_table   IN VARCHAR2,
        p_status         IN VARCHAR2,
        p_rows_processed IN NUMBER DEFAULT NULL,
        p_error_message  IN VARCHAR2 DEFAULT NULL,
        p_process_id     IN NUMBER DEFAULT NULL
    )
    RETURN NUMBER
    IS
        v_process_id NUMBER := p_process_id;
    BEGIN
        IF p_status = 'STARTED' THEN
            INSERT INTO process_log (process_name, target_table, start_time, status)
            VALUES (p_process_name, p_target_table, CURRENT_TIMESTAMP, p_status)
            RETURNING process_id INTO v_process_id;
            RETURN v_process_id;
        ELSE
            UPDATE process_log
               SET end_time       = CURRENT_TIMESTAMP,
                   rows_processed = p_rows_processed,
                   status          = p_status,
                   error_message   = p_error_message
                WHERE process_id = v_process_id;   
            RETURN v_process_id;
        END IF;
    END log_process_func;

    ----------------------------------------------------------
    -- Private Function: Log errors
    ----------------------------------------------------------
    FUNCTION log_error_func (
        p_data_source   IN VARCHAR2,
        p_target_table  IN VARCHAR2,
        p_error_message IN VARCHAR2
    )
    RETURN BOOLEAN
    IS
    BEGIN
        INSERT INTO error_log (
            error_timestamp,
            data_source,
            target_table,
            error_message
        )
        VALUES (
            CURRENT_TIMESTAMP,
            p_data_source,
            p_target_table,
            p_error_message
        );
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END log_error_func;

    ----------------------------------------------------------
    -- PROCEDURE: PROCESS STG_LOCATION
    ----------------------------------------------------------
    PROCEDURE process_stg_location AS
        v_process_id     NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message  VARCHAR2(4000);
    BEGIN
        --log process start
        v_process_id := log_process_func('Staging: stg_location', 'stg_location', 'STARTED');

        BEGIN
            --Insert From PS_WALES
            INSERT INTO stg_location (location_key, region_name, street_name, post_code, city_name, data_source)
            SELECT DISTINCT
                l.location_id,
                r.region_name,
                l.street_name,
                l.post_code,
                l.city_name,
                'PS_WALES'
            FROM location l
            LEFT JOIN region r ON l.region_id = r.region_id
            WHERE l.house_no IS NOT NULL;

            v_rows_processed := SQL%ROWCOUNT;

            ---Insert From PRCS
            INSERT INTO stg_location (location_key, post_code, data_source)
            SELECT DISTINCT
                p.reported_crime_id,
                p.crime_postcode,
                'PRCS'
            FROM pl_reported_crime p;

            v_rows_processed := v_rows_processed + SQL%ROWCOUNT;

            --Update process log with success status
            v_process_id := log_process_func('Staging: stg_location', 'stg_location', 'SUCCESS', v_rows_processed, p_process_id => v_process_id);
            COMMIT;
                EXCEPTION
            WHEN OTHERS THEN
            -- Log error
                 v_error_message := 'Error Code: ' || SQLCODE || '_' || SQLERRM;

                IF NOT log_error_func('N/A', 'stg_location', v_error_message) THEN
                    NULL; -- Or log that error logging itself failed, if needed
                END IF;

             -- Update process log with failure status
            v_process_id := log_process_func('Staging: stg_location', 'stg_location', 'FAILED', p_error_message=> v_error_message, p_process_id => v_process_id);
             -- Rollback and raise error
            ROLLBACK;
            RAISE;
        END;
    END process_stg_location;

   --------------------------------------------------------------
 -- PROCEDURE: PROCESS STG_OFFICER
   --------------------------------------------------------------
   PROCEDURE process_stg_officer AS
        v_process_id     NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message  VARCHAR2(4000);
    BEGIN
        --Log process start
        v_process_id := log_process_func('Staging: stg_officer', 'stg_officer', 'STARTED');

        BEGIN
            --Insert from PS_WALES
            INSERT INTO stg_officer (officer_key, full_name, department, rank, fk_location, data_source)
            SELECT DISTINCT
                officer_id,
                CASE
                    WHEN middle_name IS NULL THEN first_name || ' ' || last_name
                    ELSE first_name || ' ' || middle_name || ' ' || last_name
                END AS full_name,
                department,
                rank,
                loc.location_id,
                'PS_WALES'
            FROM officer o
            JOIN crime_register cr ON cr.police_id = o.officer_id
            JOIN location loc ON loc.location_id = cr.location_id;

            v_rows_processed := SQL%ROWCOUNT;

            --Insert from PRCS
            INSERT INTO stg_officer (officer_key, full_name, rank, fk_location, data_source)
            SELECT DISTINCT
                ppe.emp_id,
                ppe.emp_name,
                ppe.emp_grade,
                pa.area_id AS fk_location,
                'PRCS'
            FROM pl_police_employee ppe
            JOIN pl_work_allocation wa ON ppe.emp_id = wa.d_emp_id
            JOIN pl_reported_crime rc ON wa.s_reported_crime_id = rc.reported_crime_id
            JOIN pl_station ps ON rc.fk2_station_id = ps.station_id
            JOIN pl_area pa ON ps.fk1_area_id = pa.area_id;

            v_rows_processed := v_rows_processed + SQL%ROWCOUNT;

            --Update process log with success status 
            v_process_id := log_process_func('Staging: stg_officer', 'stg_officer', 'SUCCESS',
                             v_rows_processed, p_process_id => v_process_id);
        EXCEPTION
             WHEN OTHERS THEN
             -- Log error
             v_error_message := 'Error Code: ' || SQLCODE || '_' || SQLERRM;

              IF NOT log_error_func('N/A', 'stg_officer', v_error_message) THEN
                   NULL; -- Or log that error logging itself failed, if needed
                END IF;

             -- Update process log with failure status
           v_process_id := log_process_func('Staging: stg_officer', 'stg_officer', 'FAILED', p_error_message=> v_error_message,  p_process_id => v_process_id);

           -- Rollback and raise error
            ROLLBACK;
            RAISE;
        END;
    END process_stg_officer;


   ----------------------------------------------------------
    -- PROCEDURE: PROCESS STG_CRIME_TYPE
    ----------------------------------------------------------
    PROCEDURE process_stg_crime_type AS
        v_process_id     NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message  VARCHAR2(4000);
    BEGIN
        --Log process start
        v_process_id := log_process_func('Staging: stg_crime_type', 'stg_crime_type', 'STARTED');

        BEGIN
            --Insert from PRCS
            INSERT INTO stg_crime_type (crime_type_key, crime_type, fk_location, data_source)
            SELECT DISTINCT
                pct.crime_type_id,
                pct.crime_type_desc,
                pa.area_id,
                'PRCS'
            FROM pl_crime_type pct
            LEFT JOIN pl_reported_crime prc ON pct.crime_type_id = prc.fk1_crime_type_id
            LEFT JOIN pl_station ps ON prc.fk2_station_id = ps.station_id
            LEFT JOIN pl_area pa ON ps.fk1_area_id = pa.area_id;

            v_rows_processed := SQL%ROWCOUNT;

            --Insert from PRCS
            INSERT INTO stg_crime_type (crime_type_key, closure_status, fk_location, data_source)
            SELECT DISTINCT
                reported_crime_id,
                crime_status,
                pa.area_id,
                'PRCS'
            FROM pl_reported_crime prc
            LEFT JOIN pl_station ps ON prc.fk2_station_id = ps.station_id
            LEFT JOIN pl_area pa ON ps.fk1_area_id = pa.area_id;

            v_rows_processed := v_rows_processed + SQL%ROWCOUNT;

            --Insert from PS_WALES
            INSERT INTO stg_crime_type (crime_type_key, closure_status, crime_type, fk_location, data_source)
            SELECT DISTINCT
                cr.crime_id,
                cr.crime_status,
                cr.crime_type,
                l.location_id AS fk_location,
                'PS_WALES'
            FROM crime_register cr
            LEFT JOIN location l ON cr.location_id = l.location_id;

            v_rows_processed := v_rows_processed + SQL%ROWCOUNT;

            --Update process log with success status
            v_process_id := log_process_func('Staging: stg_crime_type', 'stg_crime_type', 'SUCCESS',
                             v_rows_processed, p_process_id => v_process_id);
            COMMIT;

       EXCEPTION
        WHEN OTHERS THEN
             -- Log error
             v_error_message := 'Error Code: ' || SQLCODE || '_' || SQLERRM;

              IF NOT log_error_func('N/A', 'stg_crime_type', v_error_message) THEN
                  NULL; -- Or log that error logging itself failed, if needed
              END IF;
            -- Update process log with failure status
            v_process_id := log_process_func('Staging: stg_crime_type', 'stg_crime_type', 'FAILED', p_error_message=> v_error_message, p_process_id => v_process_id);
             -- Rollback and raise error
            ROLLBACK;
            RAISE;
    END;
END process_stg_crime_type;

  ---------------------------------------------------------
    -- PROCEDURE: PROCESS STG_CRIME_REGISTER
  ----------------------------------------------------------
    PROCEDURE process_stg_crime_register AS
        v_process_id     NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message  VARCHAR2(4000);
    BEGIN
        --Log process start
        v_process_id := log_process_func('Staging: stg_crime_register', 'stg_crime_register', 'STARTED');

        BEGIN
            --Insert from PRCS
            INSERT INTO stg_crime_register (fk_location, fk_police_officer, fk_crime_type, closed_date, data_source)
            SELECT DISTINCT
                pa.area_id AS fk_location,
                ppe.emp_id AS fk_police_officer,
                prc.fk1_crime_type_id AS fk_crime_type,
                CASE
                    WHEN prc.date_closed IS NOT NULL THEN prc.date_closed
                    WHEN prc.date_reported IS NOT NULL THEN
                         TO_CHAR(prc.date_reported + TRUNC(DBMS_RANDOM.VALUE(1,365)), 'MM-DD-YYYY')
                END AS closed_date,
                'PRCS' AS data_source
            FROM pl_reported_crime prc
            JOIN pl_station ps ON prc.fk2_station_id = ps.station_id
            JOIN pl_area pa ON ps.fk1_area_id = pa.area_id
            JOIN pl_work_allocation pwa ON prc.reported_crime_id = pwa.s_reported_crime_id
            JOIN pl_police_employee ppe ON pwa.d_emp_id = ppe.emp_id;

            v_rows_processed := SQL%ROWCOUNT;

            --Insert from PS_WALES
            INSERT INTO stg_crime_register (fk_location, fk_police_officer, fk_crime_type, closed_date, data_source)
            SELECT DISTINCT
                l.location_id AS fk_location,
                o.officer_id AS fk_police_officer,
                cr.crime_id AS fk_crime_type,
                CASE
                    WHEN cr.closed_date IS NOT NULL THEN TO_CHAR(cr.closed_date, 'MM-DD-YYYY')
                    WHEN cr.reported_date IS NOT NULL THEN TO_CHAR(cr.reported_date + TRUNC(DBMS_RANDOM.VALUE(1, 365)), 'MM-DD-YYYY')
                    ELSE NULL
                END AS closed_date,
                'PS_WALES' AS data_source
            FROM crime_register cr
            JOIN location l ON cr.location_id = l.location_id
            JOIN officer o ON cr.police_id = o.officer_id;

            v_rows_processed := v_rows_processed + SQL%ROWCOUNT;

            ---Update process log with success status
            v_process_id := log_process_func('Staging: stg_crime_register', 'stg_crime_register', 'SUCCESS',
                             v_rows_processed, p_process_id => v_process_id);
    EXCEPTION
        WHEN OTHERS THEN
             -- Log error
             v_error_message := 'Error Code: ' || SQLCODE || '_' || SQLERRM;

             IF NOT log_error_func('N/A', 'stg_crime_register', v_error_message) THEN
                  NULL; -- Or log that error logging itself failed, if needed
              END IF;
           -- Update process log with failure status
           v_process_id := log_process_func('Staging: stg_crime_register', 'stg_crime_register', 'FAILED', p_error_message=> v_error_message, p_process_id => v_process_id);

            -- Rollback and raise error
           ROLLBACK;
           RAISE;
        END;
    END process_stg_crime_register;
END pkg_stg_load;
/   

--------------------------------------------------------------
-- RUN ALL 
--------------------------------------------------------------
--EXECUTE the procedure one by one
BEGIN
  pkg_stg_load.process_stg_location;
  pkg_stg_load.process_stg_officer;
  pkg_stg_load.process_stg_crime_type;
  pkg_stg_load.process_stg_crime_register;
END;
/

/*select * from stg_location;
select * from stg_officer;
select * from stg_crime_type;
select * from stg_crime_register;*/



