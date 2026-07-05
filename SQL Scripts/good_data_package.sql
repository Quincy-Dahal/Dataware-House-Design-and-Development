--------------------------------------------------------------
-- DROP EXISTING OBJECTS
--------------------------------------------------------------
DROP TABLE location_good_data;
DROP TABLE police_officer_good_data;

DROP TABLE location_audit;
DROP TABLE police_officer_audit;

DROP SEQUENCE seq_location_audit;
DROP SEQUENCE seq_police_officer_audit;

DROP TRIGGER trig_location_audit_pk;
DROP TRIGGER trig_police_officer_audit_pk;

DROP TRIGGER trig_location_audittrial;
DROP TRIGGER trig_police_officer_audittrial;

--------------------------------------------------------------
-- CREATE GOOD DATA TABLES
--------------------------------------------------------------
CREATE TABLE location_good_data AS
SELECT *
FROM stg_location
WHERE 1 = 0;

CREATE TABLE police_officer_good_data AS
SELECT *
FROM stg_officer
WHERE 1 = 0;

--------------------------------------------------------------
-- CREATE AUDIT SEQUENCES
--------------------------------------------------------------
CREATE SEQUENCE seq_location_audit START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_police_officer_audit START WITH 1 INCREMENT BY 1;

--------------------------------------------------------------
-- CREATE AUDIT TABLES
--------------------------------------------------------------
CREATE TABLE location_audit (
    audit_id        NUMBER NOT NULL,
    table_name      VARCHAR2(100) NOT NULL,
    location_id     NUMBER,
    column_name     VARCHAR2(100) NOT NULL,
    old_value       VARCHAR2(4000),
    new_value       VARCHAR2(4000),
    change_date     DATE DEFAULT SYSDATE NOT NULL,
    changed_by      VARCHAR2(100),
    operation_type  VARCHAR2(10) NOT NULL,
    CONSTRAINT pk_location_audit PRIMARY KEY (audit_id)
);

CREATE TABLE police_officer_audit (
    audit_id        NUMBER NOT NULL,
    table_name      VARCHAR2(100) NOT NULL,
    officer_id      NUMBER,
    column_name     VARCHAR2(100) NOT NULL,
    old_value       VARCHAR2(4000),
    new_value       VARCHAR2(4000),
    change_date     DATE DEFAULT SYSDATE NOT NULL,
    changed_by      VARCHAR2(100),
    operation_type  VARCHAR2(10) NOT NULL,
    CONSTRAINT pk_police_officer_audit PRIMARY KEY (audit_id)
);

--------------------------------------------------------------
-- AUDIT ID TRIGGERS
--------------------------------------------------------------
CREATE OR REPLACE TRIGGER trig_location_audit_pk
BEFORE INSERT ON location_audit
FOR EACH ROW
BEGIN
    :NEW.audit_id := seq_location_audit.NEXTVAL;
END;
/

CREATE OR REPLACE TRIGGER trig_police_officer_audit_pk
BEFORE INSERT ON police_officer_audit
FOR EACH ROW
BEGIN
    :NEW.audit_id := seq_police_officer_audit.NEXTVAL;
END;
/

--------------------------------------------------------------
-- AUDIT UPDATE TRIGGERS
--------------------------------------------------------------
CREATE OR REPLACE TRIGGER trig_location_audittrial
AFTER UPDATE ON location_good_data
FOR EACH ROW
DECLARE
    v_changed_by VARCHAR2(100);
BEGIN
    v_changed_by := USER;

    IF :OLD.location_key != :NEW.location_key THEN
        INSERT INTO location_audit
        VALUES (
            NULL, 'location_good_data', :NEW.location_id,
            'location_key', :OLD.location_key, :NEW.location_key,
            SYSDATE, v_changed_by, 'UPDATE'
        );
    END IF;

    IF :OLD.region_name != :NEW.region_name THEN
        INSERT INTO location_audit
        VALUES (
            NULL, 'location_good_data', :NEW.location_id,
            'region_name', :OLD.region_name, :NEW.region_name,
            SYSDATE, v_changed_by, 'UPDATE'
        );
    END IF;

    IF :OLD.street_name != :NEW.street_name THEN
        INSERT INTO location_audit
        VALUES (
            NULL, 'location_good_data', :NEW.location_id,
            'street_name', :OLD.street_name, :NEW.street_name,
            SYSDATE, v_changed_by, 'UPDATE'
        );
    END IF;

    IF :OLD.post_code != :NEW.post_code THEN
        INSERT INTO location_audit
        VALUES (
            NULL, 'location_good_data', :NEW.location_id,
            'post_code', :OLD.post_code, :NEW.post_code,
            SYSDATE, v_changed_by, 'UPDATE'
        );
    END IF;

    IF :OLD.city_name != :NEW.city_name THEN
        INSERT INTO location_audit
        VALUES (
            NULL, 'location_good_data', :NEW.location_id,
            'city_name', :OLD.city_name, :NEW.city_name,
            SYSDATE, v_changed_by, 'UPDATE'
        );
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trig_police_officer_audittrial
AFTER UPDATE ON police_officer_good_data
FOR EACH ROW
DECLARE
    v_changed_by VARCHAR2(100);
BEGIN
    v_changed_by := USER;
    
    IF :OLD.officer_key != :NEW.officer_key THEN
        INSERT INTO police_officer_audit
        VALUES (
            NULL, 'police_officer_good_data', :NEW.officer_id,
            'officer_key', :OLD.officer_key, :NEW.officer_key,
            SYSDATE, v_changed_by, 'UPDATE'
        );
    END IF;

    IF :OLD.full_name != :NEW.full_name THEN
        INSERT INTO police_officer_audit
        VALUES (
            NULL, 'police_officer_good_data', :NEW.officer_id,
            'full_name', :OLD.full_name, :NEW.full_name,
            SYSDATE, v_changed_by, 'UPDATE'
        );
    END IF;

    IF :OLD.department != :NEW.department THEN
        INSERT INTO police_officer_audit
        VALUES (
            NULL, 'police_officer_good_data', :NEW.officer_id,
            'department', :OLD.department, :NEW.department,
            SYSDATE, v_changed_by, 'UPDATE'
        );
    END IF;

    IF :OLD.rank != :NEW.rank THEN
        INSERT INTO police_officer_audit
        VALUES (
            NULL, 'police_officer_good_data', :NEW.officer_id,
            'rank', :OLD.rank, :NEW.rank,
            SYSDATE, v_changed_by, 'UPDATE'
        );
    END IF;
END;
/

CREATE OR REPLACE PACKAGE good_data_pkg AS
    PROCEDURE identify_location_good_data;
    PROCEDURE identify_officer_good_data;
    PROCEDURE process_location_good_data;
    PROCEDURE process_police_officer_good_data;
    PROCEDURE update_stg_crime_type_data;
END good_data_pkg;
/

CREATE OR REPLACE PACKAGE BODY good_data_pkg AS

    ----------------------------------------------------------
    -- FUNCTION: LOG PROCESS
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
                SET end_time = CURRENT_TIMESTAMP, rows_processed = p_rows_processed, status = p_status, error_message = SUBSTR(p_error_message, 1, 4000)
                WHERE process_id = v_process_id;
            RETURN v_process_id;
        END IF;
    END log_process_func;

    ----------------------------------------------------------
    -- FUNCTION: LOG ERROR
    ----------------------------------------------------------
    FUNCTION log_error_func (
        p_data_source   IN VARCHAR2,
        p_target_table  IN VARCHAR2,
        p_error_message IN VARCHAR2
    )
    RETURN BOOLEAN
    IS
    BEGIN
        INSERT INTO error_log (error_timestamp, data_source, target_table, error_message)
        VALUES (CURRENT_TIMESTAMP, p_data_source, p_target_table, SUBSTR(p_error_message, 1, 4000));
        RETURN TRUE;
        EXCEPTION
            WHEN OTHERS THEN
            RETURN FALSE;
    END log_error_func;

    ----------------------------------------------------------
    -- PROCEDURE: IDENTIFY LOCATION GOOD DATA
    ----------------------------------------------------------
    PROCEDURE identify_location_good_data AS
        v_process_id     NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message  VARCHAR2(4000);
    BEGIN
        v_process_id := log_process_func(
            'good_data: location_good_data',
            'location_good_data',
            'STARTED'
        );

        BEGIN
            INSERT INTO location_good_data
            SELECT *
            FROM stg_location
            WHERE location_key IS NOT NULL
              AND region_name  IS NOT NULL
              AND street_name  IS NOT NULL
              AND post_code    IS NOT NULL
              AND city_name    IS NOT NULL
              AND NOT REGEXP_LIKE(region_name, '^[0-9]+$')
              AND NOT REGEXP_LIKE(street_name, '^[0-9]+$')
              AND NOT REGEXP_LIKE(city_name, '^[0-9]+$')
              AND (
                    REGEXP_LIKE(TRIM(region_name), '^[a-z]+( [a-z]+)*$')
                 OR REGEXP_LIKE(TRIM(region_name), '^[A-Z]+( [A-Z]+)*$')
                 OR REGEXP_LIKE(TRIM(region_name),
                     '^[A-Z][a-z]*( [A-Z][a-z]*)*(, [A-Z][a-z]*)*$')
                )
              AND (
                    REGEXP_LIKE(TRIM(city_name), '^[a-z]+( [a-z]+)*$')
                 OR REGEXP_LIKE(TRIM(city_name), '^[A-Z]+( [A-Z]+)*$')
                 OR REGEXP_LIKE(TRIM(city_name),
                     '^[A-Z][a-z]*( [A-Z][a-z]*)*$')
                );

                v_rows_processed := SQL%ROWCOUNT;

           UPDATE location_good_data
            SET region_name = UPPER(region_name),
                street_name = UPPER(street_name),
                city_name = UPPER(city_name)
             WHERE region_name IS NOT NULL
                   AND street_name IS NOT NULL
                AND city_name IS NOT NULL;

            v_rows_processed := v_rows_processed + sql%rowcount;

           -- Update process log with success status
           v_process_id := log_process_func('good_data: location_good_data', 'location_good_data', 'SUCCESS', v_rows_processed,  p_process_id => v_process_id);


EXCEPTION
            WHEN OTHERS THEN
               v_error_message := 'Error Code: ' || SQLCODE || '_' || SQLERRM;
                IF NOT log_error_func('N/A', 'location_good_data', v_error_message) THEN
                   NULL; -- Or log that error logging itself failed, if needed
                END IF;
               -- Update process log with failure status
              v_process_id := log_process_func('good_data: location_good_data', 'location_good_data', 'FAILED',  p_error_message =>v_error_message, p_process_id => v_process_id);
            RAISE;

          COMMIT;
        DBMS_OUTPUT.PUT_LINE('Data inserted and uppercase transformation applied to location_good_data.');
       END;
    END identify_location_good_data;

    ----------------------------------------------------------
    -- PROCEDURE: IDENTIFY OFFICER GOOD DATA
    ----------------------------------------------------------
    PROCEDURE identify_officer_good_data AS
        v_process_id     NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message  VARCHAR2(4000);
    BEGIN
        v_process_id := log_process_func('good_data: police_officer_good_data', 'police_officer_good_data', 'STARTED');
        BEGIN
            INSERT INTO police_officer_good_data
            SELECT *
            FROM stg_officer
            WHERE officer_key IS NOT NULL
              AND full_name   IS NOT NULL
              AND department  IS NOT NULL
              AND rank        IS NOT NULL
              AND NOT REGEXP_LIKE(full_name, '^[0-9]+$')
              AND NOT REGEXP_LIKE(department, '^[0-9]+$')
              AND (
                    REGEXP_LIKE(TRIM(full_name), '^[a-z]+( [a-z]+)*$')               -- All lowercase
                    or REGEXP_LIKE(TRIM(full_name), '^[A-Z]+( [A-Z]+)*$')            -- All uppercase
                    or REGEXP_LIKE(TRIM(full_name), '^[A-Z][a-z]*( [A-Z][a-z]*)*$')  -- Initial capital
                )
              AND (
                    -- Department must be either all uppercase, all lowercase, or proper case
                    REGEXP_LIKE(TRIM(department), '^[a-z]+( [a-z]+)*$')               -- All lowercase
                    or REGEXP_LIKE(TRIM(department), '^[A-Z]+( [A-Z]+)*$')            -- All uppercase
                    or REGEXP_LIKE(TRIM(department), '^[A-Z][a-z]*( [A-Z][a-z]*)*$')  -- (Initial capital)
                );
                DBMS_OUTPUT.PUT_LINE('Rows Inserted' || v_rows_processed);

            UPDATE police_officer_good_data
            SET full_name = UPPER(full_name),
            department = UPPER(department)
            WHERE full_name IS NOT NULL
            AND department IS NOT NULL;

            v_rows_processed := v_rows_processed + sql%rowcount;

             -- Update process log with success status
            v_process_id := log_process_func('good_data: police_officer_good_data', 'police_officer_good_data', 'SUCCESS', v_rows_processed, p_process_id => v_process_id);

        EXCEPTION
            WHEN OTHERS THEN
              v_error_message := 'Error Code: ' || SQLCODE || '_' || SQLERRM;
                IF NOT log_error_func('N/A', 'police_officer_good_data', v_error_message) THEN
                    NULL; -- Or log that error logging itself failed, if needed
                END IF;

             -- Update process log with failure status
              v_process_id := log_process_func('good_data: police_officer_good_data', 'police_officer_good_data', 'FAILED',  p_error_message =>v_error_message, p_process_id => v_process_id);
              RAISE;
        END;
    END identify_officer_good_data;

----------------------------------------------------------
    -- PROCEDURE: PROCESS LOCATION GOOD DATA
----------------------------------------------------------    
    PROCEDURE process_location_good_data AS
       v_process_id NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message VARCHAR2(4000);
    BEGIN
    -- Log process start
        v_process_id := log_process_func('good_data: location_bad_data', 'location_bad_data', 'STARTED');
     BEGIN

            UPDATE location_bad_data
            SET region_name = 'UNKNOWN'
            WHERE region_name IS NULL;

            v_rows_processed := sql%rowcount;
           UPDATE location_bad_data
            SET street_name = 'UNKNOWN'
             WHERE street_name IS NULL;

             v_rows_processed := v_rows_processed + sql%rowcount;
             UPDATE location_bad_data
             SET post_code = 'UNKNOWN'
            WHERE post_code IS NULL;

              v_rows_processed := v_rows_processed + sql%rowcount;
             UPDATE location_bad_data
              SET city_name = 'UNKNOWN'
             WHERE city_name IS NULL;

            v_rows_processed := v_rows_processed + sql%rowcount;
            UPDATE location_bad_data
              SET region_name = 'UNKNOWN'
              WHERE REGEXP_LIKE(region_name, '^[0-9]+$');

              v_rows_processed := v_rows_processed + sql%rowcount;
           UPDATE location_bad_data
             SET city_name = 'UNKNOWN'
              WHERE REGEXP_LIKE(city_name, '^[0-9]+$');

             v_rows_processed := v_rows_processed + sql%rowcount;
            UPDATE location_bad_data
            SET region_name = UPPER(TRIM(region_name))
            WHERE region_name IS NOT NULL;

           v_rows_processed := v_rows_processed + sql%rowcount;
             UPDATE location_bad_data
             SET city_name = UPPER(TRIM(city_name))
            WHERE city_name IS NOT NULL;

            v_rows_processed := v_rows_processed + sql%rowcount;
             UPDATE location_bad_data
             SET street_name = UPPER(TRIM(street_name))
             WHERE street_name IS NOT NULL;

            v_rows_processed := v_rows_processed + sql%rowcount;

            -- Insert the cleaned data from the bad table into the good table
            INSERT INTO location_good_data
            SELECT *
            FROM location_bad_data
            WHERE location_key IS NOT NULL
            AND region_name IS NOT NULL
            AND street_name IS NOT NULL
            AND post_code IS NOT NULL
            AND city_name IS NOT NULL;

            v_rows_processed := v_rows_processed + sql%rowcount;

           -- Update process log with success status
             v_process_id := log_process_func('good_data: location_bad_data', 'location_bad_data', 'SUCCESS', v_rows_processed,  p_process_id => v_process_id);

        EXCEPTION
            WHEN OTHERS THEN
              v_error_message := 'Error Code: ' || SQLCODE || '_' || SQLERRM;
              IF NOT log_error_func('N/A', 'location_bad_data', v_error_message) THEN
                  NULL; -- Or log that error logging itself failed, if needed
                END IF;

             -- Update process log with failure status
            v_process_id := log_process_func('good_data: location_bad_data', 'location_bad_data', 'FAILED',  p_error_message =>v_error_message, p_process_id => v_process_id);

            RAISE;
        END;
    END process_location_good_data;

    ----------------------------------------------------------
    -- PROCEDURE: PROCESS OFFICER GOOD DATA
    ----------------------------------------------------------
    PROCEDURE process_police_officer_good_data AS
        v_process_id NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message VARCHAR2(4000);
    BEGIN
    -- Log process start
          v_process_id := log_process_func('good_data: process_police_officer_bad_data', 'police_officer_bad_data', 'STARTED');
         BEGIN

            UPDATE police_officer_bad_data
            SET full_name = 'UNKNOWN'
            WHERE full_name IS NULL;

            v_rows_processed := sql%rowcount;

           UPDATE police_officer_bad_data
             SET department = 'UNKNOWN'
           WHERE department IS NULL;

            v_rows_processed := v_rows_processed + sql%rowcount;
          UPDATE police_officer_bad_data
            SET rank = 'UNKNOWN'
           WHERE rank IS NULL;
           
           v_rows_processed := v_rows_processed + sql%rowcount;
            UPDATE police_officer_bad_data
              SET full_name = 'UNKNOWN'
          WHERE REGEXP_LIKE(full_name, '^[0-9]+$');

            v_rows_processed := v_rows_processed + sql%rowcount;
             UPDATE police_officer_bad_data
             SET department = 'UNKNOWN'
              WHERE REGEXP_LIKE(department, '^[0-9]+$');

           v_rows_processed := v_rows_processed + sql%rowcount;
             UPDATE police_officer_bad_data
             SET full_name = UPPER(TRIM(full_name))
             WHERE full_name IS NOT NULL;

            v_rows_processed := v_rows_processed + sql%rowcount;

             UPDATE police_officer_bad_data
            SET department = UPPER(TRIM(department))
             WHERE department IS NOT NULL;

           v_rows_processed := v_rows_processed + sql%rowcount;

           
            -- Insert the cleaned data from the bad table into the good table
            INSERT INTO police_officer_good_data
            SELECT *
            FROM police_officer_bad_data
            WHERE officer_key IS NOT NULL
            AND full_name IS NOT NULL
            AND department IS NOT NULL
            AND rank IS NOT NULL;

            v_rows_processed := v_rows_processed + sql%rowcount;

           -- Update process log with success status
            v_process_id := log_process_func('good_data: process_police_officer_bad_data', 'police_officer_bad_data', 'SUCCESS', v_rows_processed, p_process_id => v_process_id);
        EXCEPTION
              WHEN OTHERS THEN
                v_error_message := 'Error Code: ' || SQLCODE || '_' || SQLERRM;
                IF NOT log_error_func('N/A', 'police_officer_bad_data', v_error_message) THEN
                   NULL; -- Or log that error logging itself failed, if needed
                END IF;
                -- Update process log with failure status
            v_process_id := log_process_func('good_data: process_police_officer_bad_data', 'police_officer_bad_data', 'FAILED', p_error_message => v_error_message, p_process_id => v_process_id);
            RAISE;

         COMMIT;
        DBMS_OUTPUT.PUT_LINE('Processing for police officer bad data completed.');
      END;
    END process_police_officer_good_data;

    ----------------------------------------------------------
    -- PROCEDURE: UPDATE STG CRIME TYPE
    ----------------------------------------------------------
    PROCEDURE update_stg_crime_type_data AS
        v_process_id     NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message  VARCHAR2(4000);
    BEGIN
        --log process start
            v_process_id := log_process_func('Update data: stg_crime_type', 'stg_crime_type', 'STARTED');
        BEGIN
               UPDATE stg_crime_type
             SET closure_status = 'CLOSED'
              WHERE closure_status IS NULL;
             v_rows_processed := sql%rowcount;

           UPDATE stg_crime_type
            SET crime_type = 'UNKNOWN'
              WHERE crime_type IS NULL;

              v_rows_processed := v_rows_processed + sql%rowcount;
               -- Update process log with success status
               v_process_id := log_process_func('Update data: stg_crime_type', 'stg_crime_type', 'SUCCESS', v_rows_processed,  p_process_id => v_process_id);
         EXCEPTION
                WHEN OTHERS THEN
                  v_error_message := 'Error Code: ' || SQLCODE || '_' || SQLERRM;
                  IF NOT log_error_func('N/A', 'stg_crime_type', v_error_message) THEN
                       NULL; -- Or log that error logging itself failed, if needed
                   END IF;
                   -- Update process log with failure status
             v_process_id := log_process_func('Update data: stg_crime_type', 'stg_crime_type', 'FAILED',  p_error_message => v_error_message, p_process_id => v_process_id);
                RAISE;

             COMMIT;
          DBMS_OUTPUT.PUT_LINE('Update data for stg_crime_type has been completed successfully.');

        END;
    END update_stg_crime_type_data;

END good_data_pkg;
/

--------------------------------------------------------------
-- FINAL CHECK
--EXECUTE the procedure one by one
--------------------------------------------------------------
BEGIN
    good_data_pkg.identify_location_good_data;
    good_data_pkg.identify_officer_good_data;
    good_data_pkg.process_location_good_data;
    good_data_pkg.process_police_officer_good_data;
    good_data_pkg.update_stg_crime_type_data;
END;
/

/*select* from location_good_data order by location_id;
select* from police_officer_good_data order by officer_id;*/