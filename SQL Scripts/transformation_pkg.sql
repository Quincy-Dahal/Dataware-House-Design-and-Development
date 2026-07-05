--------------------------------------------------------------
-- DROP EXISTING TRANSFORMATION SEQUENCES
--------------------------------------------------------------
DROP SEQUENCE trans_location_seq;
DROP SEQUENCE trans_crime_type_seq;
DROP SEQUENCE trans_police_officer_seq;
DROP SEQUENCE trans_crime_register_seq;

--------------------------------------------------------------
-- DROP EXISTING TRANSFORMATION TRIGGERS
--------------------------------------------------------------
DROP TRIGGER trans_crime_type_trig;
DROP TRIGGER trans_location_trig;
DROP TRIGGER trans_police_officer_trig;
DROP TRIGGER trans_crime_register_trig;

--------------------------------------------------------------
-- DROP EXISTING TRANSFORMATION TABLES
--------------------------------------------------------------
DROP TABLE trans_location;
DROP TABLE trans_crime_type;
DROP TABLE trans_police_officer;
DROP TABLE trans_crime_register;

--------------------------------------------------------------
-- CREATE TRANSFORMATION SEQUENCES
--------------------------------------------------------------
CREATE SEQUENCE trans_location_seq
START WITH 1
INCREMENT BY 1;

CREATE SEQUENCE trans_crime_type_seq
START WITH 1
INCREMENT BY 1;

CREATE SEQUENCE trans_police_officer_seq
START WITH 1
INCREMENT BY 1;

CREATE SEQUENCE trans_crime_register_seq
START WITH 1
INCREMENT BY 1;

--------------------------------------------------------------
-- CREATE TRANSFORMATION TABLE: TRANS_LOCATION
--------------------------------------------------------------
CREATE TABLE trans_location (
    location_id     INTEGER NOT NULL,     -- Surrogate key
    location_key    INTEGER,              
    region_name     VARCHAR(20),
    street_name     VARCHAR(20),
    post_code       VARCHAR(20),
    city_name       VARCHAR(20),
    data_source     VARCHAR(40),            -- Source system (PRCS / PS_WALES)
    PRIMARY KEY (location_id)
);


--------------------------------------------------------------
-- CREATE TRANSFORMATION TABLE: TRANS_CRIME_TYPE
--------------------------------------------------------------
CREATE TABLE trans_crime_type (
    crimetype_id    INTEGER NOT NULL,      -- Surrogate key
    crime_type_key  INTEGER,               -- Original crime type identifier
    closure_status  VARCHAR(20),
    crime_type      VARCHAR(40),
    fk_location     INTEGER,               -- Foreign key to location
    data_source     VARCHAR(40),
    PRIMARY KEY (crimetype_id)
);


--------------------------------------------------------------
-- CREATE TRANSFORMATION TABLE: TRANS_POLICE_OFFICER
--------------------------------------------------------------
CREATE TABLE trans_police_officer (
    officer_id          INTEGER NOT NULL,  -- Surrogate key
    officer_key         INTEGER,            -- Original officer/employee ID
    full_name           VARCHAR(40),
    department          VARCHAR(20),
    rank                INTEGER,
    fk_location         INTEGER,            -- Associated location key
    data_source         VARCHAR(40),
    PRIMARY KEY (officer_id)
);


--------------------------------------------------------------
-- CREATE TRANSFORMATION TABLE: TRANS_CRIME_REGISTER
--------------------------------------------------------------
CREATE TABLE trans_crime_register (
    crime_register_id   INTEGER NOT NULL,  -- Surrogate key
    fk_location         INTEGER,
    fk_police_officer   INTEGER,
    fk_crime_type       INTEGER,
    closed_date         VARCHAR(50),
    data_source         VARCHAR(40),
    PRIMARY KEY (crime_register_id)
);


--------------------------------------------------------------
-- CREATE TRIGGERS FOR SURROGATE KEY GENERATION
--------------------------------------------------------------

-- Trigger for TRANS_CRIME_TYPE
CREATE OR REPLACE TRIGGER trans_crime_type_trig
BEFORE INSERT ON trans_crime_type
FOR EACH ROW
BEGIN
    IF :NEW.crimetype_id IS NULL THEN
        SELECT trans_crime_type_seq.NEXTVAL
        INTO :NEW.crimetype_id
        FROM SYS.DUAL;
    END IF;
END;
/

-- Trigger for TRANS_LOCATION
CREATE OR REPLACE TRIGGER trans_location_trig
BEFORE INSERT ON trans_location
FOR EACH ROW
BEGIN
    IF :NEW.location_id IS NULL THEN
        SELECT trans_location_seq.NEXTVAL
        INTO :NEW.location_id
        FROM SYS.DUAL;
    END IF;
END;
/

-- Trigger for TRANS_POLICE_OFFICER
CREATE OR REPLACE TRIGGER trans_police_officer_trig
BEFORE INSERT ON trans_police_officer
FOR EACH ROW
BEGIN
    IF :NEW.officer_id IS NULL THEN
        SELECT trans_police_officer_seq.NEXTVAL
        INTO :NEW.officer_id
        FROM SYS.DUAL;
    END IF;
END;
/

-- Trigger for TRANS_CRIME_REGISTER
CREATE OR REPLACE TRIGGER trans_crime_register_trig
BEFORE INSERT ON trans_crime_register
FOR EACH ROW
BEGIN
    IF :NEW.crime_register_id IS NULL THEN
        SELECT trans_crime_register_seq.NEXTVAL
        INTO :NEW.crime_register_id
        FROM SYS.DUAL;
    END IF;
END;
/

--------------------------------------------------------------
-- PACKAGE: PKG_LOADING 
--------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_transformation AS
    PROCEDURE load_trans_location;
    PROCEDURE load_trans_police_officer;
    PROCEDURE load_trans_crime_type;
    PROCEDURE load_trans_crime_register;
END pkg_transformation;
/
--------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY pkg_transformation AS
--------------------------------------------------------------
--TRANS_LOCATION
--------------------------------------------------------------
 --- Private Function to insert into the process log
    FUNCTION log_process_func (
        p_process_name IN VARCHAR2,
        p_target_table IN VARCHAR2,
        p_status IN VARCHAR2,
        p_rows_processed IN NUMBER DEFAULT NULL,
        p_error_message IN VARCHAR2 DEFAULT NULL,
        p_process_id IN NUMBER DEFAULT NULL
    )
    RETURN NUMBER
    IS
        v_process_id NUMBER := p_process_id;
    BEGIN
       IF p_status = 'STARTED' THEN
            INSERT INTO process_log (process_name, target_table, start_time, status)
            VALUES (p_process_name, p_target_table, CURRENT_TIMESTAMP, p_status)
            returning process_id into v_process_id;
            RETURN v_process_id;

        ELSE
            UPDATE process_log
                SET end_time = CURRENT_TIMESTAMP, rows_processed = p_rows_processed, status = p_status, error_message = p_error_message
                WHERE process_id = v_process_id;
             RETURN v_process_id;
        END IF;
    END log_process_func;

    -- Private Function to insert into the error log
    FUNCTION log_error_func (
        p_data_source IN VARCHAR2,
        p_target_table IN VARCHAR2,
         p_error_message IN VARCHAR2
    )
    RETURN  BOOLEAN
    IS
     BEGIN
        INSERT INTO error_log (error_timestamp, data_source, target_table, error_message)
        VALUES (CURRENT_TIMESTAMP, p_data_source, p_target_table, p_error_message);
        RETURN TRUE;
        EXCEPTION
            WHEN OTHERS THEN
            RETURN FALSE;
    END log_error_func;

   -- Procedure to load data into trans_location
    PROCEDURE load_trans_location AS
        v_process_id NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message VARCHAR2(4000);
    BEGIN
        -- Log process start
        v_process_id := log_process_func(
            'Transformation: trans_location', 
            'trans_location', 
            'STARTED'
        );    

    BEGIN
           -- Insert data from good data table
            INSERT INTO trans_location (location_key, region_name, street_name, post_code, city_name, data_source)
            SELECT DISTINCT location_key, region_name, street_name, post_code, city_name, data_source
            FROM location_good_data;

            -- Update rows processed
            v_rows_processed := sql%rowcount;

           -- Update process log with success status
           v_process_id := log_process_func(
            'Transformation: trans_location',
            'trans_location',
            'SUCCESS',
            v_rows_processed,
            NULL,
            v_process_id
        );

    EXCEPTION
        WHEN OTHERS THEN
            -- Log error
            v_error_message := 'Error Code: ' || SQLCODE || '_' || SQLERRM;
           IF NOT log_error_func('N/A', 'trans_location', v_error_message) THEN
                   NULL; -- Or log that error logging itself failed, if needed
                END IF;
            -- Update process log with failure status
            v_process_id := log_process_func(
                'Transformation: trans_location',
                'trans_location',
                'FAILED',
                NULL,
                v_error_message,
                v_process_id
            );           
            -- Rollback and raise error
            ROLLBACK;
           RAISE;
    END;
    END load_trans_location;

--------------------------------------------------------------
-- TRANS_POLICE_OFFICER
--------------------------------------------------------------
    PROCEDURE load_trans_police_officer AS
        v_process_id     NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message  VARCHAR2(4000);
    BEGIN
        -- Log process start
        v_process_id := log_process_func(
            'Transformation: trans_location', 
            'trans_location', 
            'STARTED'
        );
    BEGIN
           -- Insert data from good data table
             INSERT INTO trans_police_officer (officer_key, full_name, department, rank, fk_location, data_source)
            SELECT DISTINCT officer_key, full_name, department, rank, fk_location, data_source
             FROM police_officer_good_data;

           -- Update rows processed
            v_rows_processed := sql%rowcount;
            
             -- Update process log with success status
        v_process_id := log_process_func(
            'Transformation: trans_location',
            'trans_location',
            'SUCCESS',
            v_rows_processed,
            NULL,
            v_process_id
        );
        EXCEPTION
            WHEN OTHERS THEN
           -- Log error
           v_error_message := 'Error Code: ' || SQLCODE || '_' || SQLERRM;
           IF NOT log_error_func('N/A', 'trans_police_officer', v_error_message) THEN
                   NULL; -- Or log that error logging itself failed, if needed
                END IF;
           -- Update process log with failure status
            v_process_id := log_process_func(
                'Transformation: trans_location',
                'trans_location',
                'FAILED',
                NULL,
                v_error_message,
                v_process_id
            );            
            -- Rollback and raise error
            ROLLBACK;
           RAISE;
        END;
    END load_trans_police_officer;

--------------------------------------------------------------
--TRANS_CRIME_TYPE
--------------------------------------------------------------
PROCEDURE load_trans_crime_type AS
        v_process_id NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message VARCHAR2(4000);
    BEGIN
        -- Log process start
        v_process_id := log_process_func(
            'Transformation: trans_location', 
            'trans_location', 
            'STARTED'
        );    
            
    BEGIN
           -- Insert data from staging table
            INSERT INTO trans_crime_type(crime_type_key, closure_status, crime_type, fk_location, data_source)
            SELECT DISTINCT
                crime_type_key,
                closure_status,
                upper(crime_type),
                fk_location,
                data_source
            FROM stg_crime_type;
            
             -- Update rows processed
              v_rows_processed := sql%rowcount;
              
            -- Update process log with success status
        v_process_id := log_process_func(
            'Transformation: trans_location',
            'trans_location',
            'SUCCESS',
            v_rows_processed,
            NULL,
            v_process_id
        );    

        EXCEPTION
        WHEN OTHERS THEN
           -- Log error
           v_error_message := 'Error Code: ' || SQLCODE || '_' || SQLERRM;
           IF NOT log_error_func('N/A', 'trans_crime_type', v_error_message) THEN
                   NULL; -- Or log that error logging itself failed, if needed
            END IF;
           -- Update process log with failure status
            v_process_id := log_process_func(
                'Transformation: trans_location',
                'trans_location',
                'FAILED',
                NULL,
                v_error_message,
                v_process_id
            );          
        -- Rollback and raise error
        ROLLBACK;
        RAISE;
    END;
   END load_trans_crime_type;

--------------------------------------------------------------
-- TRANS_CRIME_REGISTER
--------------------------------------------------------------
   PROCEDURE load_trans_crime_register AS
        v_process_id NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message VARCHAR2(4000);
    BEGIN
        -- Log process start
        v_process_id := log_process_func(
            'Transformation: trans_location', 
            'trans_location', 
            'STARTED'
        );    
    BEGIN
           -- Insert data from staging table
            INSERT INTO trans_crime_register(fk_location, fk_police_officer, fk_crime_type, closed_date, data_source)
            SELECT DISTINCT
                fk_location,
                fk_police_officer,
                fk_crime_type,
                closed_date,
                data_source
            FROM stg_crime_register;
            
           -- Update rows processed
            v_rows_processed := sql%rowcount;
            
            -- Update process log with success status
            v_process_id := log_process_func(
                'Transformation: trans_location',
                'trans_location',
                'SUCCESS',
                v_rows_processed,
                NULL,
                v_process_id
            );

      EXCEPTION
        WHEN OTHERS THEN
           -- Log error
           v_error_message := 'Error Code: ' || SQLCODE || '_' || SQLERRM;
             IF NOT log_error_func('N/A', 'trans_crime_register', v_error_message) THEN
                    NULL; -- Or log that error logging itself failed, if needed
                END IF;
            -- Update process log with failure status
            v_process_id := log_process_func(
                'Transformation: trans_location',
                'trans_location',
                'FAILED',
                NULL,
                v_error_message,
                v_process_id
            );          
        -- Rollback and raise error
        ROLLBACK;
        RAISE;
    END;
    END load_trans_crime_register;
END pkg_transformation;
/

--------------------------------------------------------------
-- EXECUTE TRANSFORMATION PACKAGE PROCEDURES
--------------------------------------------------------------
BEGIN
  pkg_transformation.load_trans_location;        -- Load transformed location data
  pkg_transformation.load_trans_police_officer;  -- Load transformed police officer data
  pkg_transformation.load_trans_crime_type;      -- Load transformed crime type data
  pkg_transformation.load_trans_crime_register;  -- Load transformed crime register data
END;
/

--------------------------------------------------------------
-- VERIFY TRANSFORMATION OUTPUT
--------------------------------------------------------------
/*select* from trans_location order by location_id;
select* from trans_police_officer order by officer_id;
select* from trans_crime_type order by crimetype_id;
select* from trans_crime_register order by crime_register_id;*/