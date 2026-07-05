CREATE OR REPLACE PACKAGE loading_pkg AS
    PROCEDURE load_dim_location;
    PROCEDURE load_dim_officer;
    PROCEDURE load_dim_crime_type;
    PROCEDURE load_dim_time;
    PROCEDURE load_fact_table;
    PROCEDURE load_from_leeds;
END loading_pkg;
/

--------------------------------------------------------------
-- LOADING PACKAGE
--------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY loading_pkg AS
-- Private Function to insert into the process log
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

--------------------------------------------------------------
-- LOAD DIM_LOCATION FROM TRANS_LOCATION
--------------------------------------------------------------
PROCEDURE load_dim_location AS
        v_process_id NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message VARCHAR2(4000);  -- Declare a variable to hold error message
    BEGIN
          -- Log process start
        v_process_id := log_process_func(
            'Loading: dim_location', 
            'dim_location', 
            'STARTED'
        );

        BEGIN
            INSERT INTO dim_location(location_key, region_name, street_name, post_code, city_name, data_source)
            SELECT 
                location_key,
                region_name,
                street_name,
                post_code,
                city_name,
                data_source
            FROM 
                trans_location;

            -- add the rows processed in this step
            v_rows_processed := SQL%ROWCOUNT;

            
            -- Update process log with success status
           v_process_id := log_process_func(
            'Loading: dim_location', 
            'dim_location', 
            'SUCCESS',
            v_rows_processed,
            NULL,
            v_process_id);
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                --capture the error message using SQLERRM
                v_error_message:= 'Error Code: ' || SQLCODE || '_' || SQLERRM;
                
            IF NOT log_error_func('N/A', 'dim_location', v_error_message) THEN
                NULL; -- Or log that error logging itself failed, if needed
            END IF;
            -- Update process log with failure status
            v_process_id := log_process_func(
                'Loading: dim_location',
                'dim_location',
                'FAILED',
                NULL,
                v_error_message,
                v_process_id
            ); 
                
                RAISE;
        END;
    END load_dim_location;

--------------------------------------------------------------
-- LOAD DIM_POLICE_OFFICER FROM TRANS_POLICE_OFFICER
--------------------------------------------------------------
PROCEDURE load_dim_officer AS
        v_process_id NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message VARCHAR2(4000);  -- Declare a variable to hold error message
    BEGIN
        -- Log process start
        v_process_id := log_process_func(
            'Loading: dim_officer', 
            'dim_officer', 
            'STARTED'
        );
        BEGIN 

            INSERT INTO dim_officer(
                officer_key,
                full_name,
                department,
                rank,
                data_source
            )
            SELECT
                officer_key,
                full_name,
                department,
                rank,
                data_source
            FROM
                trans_police_officer;

            -- add the rows processed in this step
            v_rows_processed := SQL%ROWCOUNT;

            -- Update process log with success status
           v_process_id := log_process_func(
            'Loading: dim_officer', 
            'dim_officer', 
            'SUCCESS',
            v_rows_processed,
            NULL,
            v_process_id);

        EXCEPTION
            WHEN OTHERS THEN
                --capture the error message using SQLERRM
                v_error_message:= 'Error Code: ' || SQLCODE || '_' || SQLERRM;
                
                IF NOT log_error_func('N/A', 'dim_officer', v_error_message) THEN
                    NULL; -- Or log that error logging itself failed, if needed
                END IF;
                -- Update process log with failure status
                v_process_id := log_process_func(
                    'Loading: dim_officer',
                    'dim_officer',
                    'FAILED',
                    NULL,
                    v_error_message,
                    v_process_id
            ); 
                RAISE;
        END;
    END load_dim_officer;

--------------------------------------------------------------
-- LOAD DIM_CRIME_TYPE FROM TRANS_CRIME_TYPE
--------------------------------------------------------------
PROCEDURE load_dim_crime_type AS
        v_process_id NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message VARCHAR2(4000);  -- Declare a variable to hold error message
    BEGIN
        -- Log process start
        v_process_id := log_process_func(
            'Loading: dim_crime_type', 
            'dim_crime_type', 
            'STARTED'
        );
        BEGIN

            INSERT INTO dim_crime_type(
                crime_type_key,
                closure_status,
                crime_type,
                data_source
            )
            SELECT
                crime_type_key,
                closure_status,
                crime_type,
                data_source
            FROM
                trans_crime_type;

            -- add the rows processed in this step
            v_rows_processed := SQL%ROWCOUNT;

            -- Update process log with success status
            v_process_id := log_process_func(
            'Loading: dim_crime_type', 
            'dim_crime_type', 
            'SUCCESS',
            v_rows_processed,
            NULL,
            v_process_id);

        EXCEPTION
            WHEN OTHERS THEN
                --capture the error message using SQLERRM
                v_error_message:= 'Error Code: ' || SQLCODE || '_' || SQLERRM;
                
                IF NOT log_error_func('N/A', 'dim_crime_type', v_error_message) THEN
                    NULL; -- Or log that error logging itself failed, if needed
                END IF;
                -- Update process log with failure status
                v_process_id := log_process_func(
                    'Loading: dim_crime_type',
                    'dim_crime_type',
                    'FAILED',
                    NULL,
                    v_error_message,
                    v_process_id
            ); 
                RAISE;
        END;
    END load_dim_crime_type;


--------------------------------------------------------------
-- LOAD DIM_TIME FROM TRANS_CRIME_REGISTER
--------------------------------------------------------------
    PROCEDURE load_dim_time AS
        v_process_id NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message VARCHAR2(4000);  -- Declare a variable to hold error message
    BEGIN
        -- Log process start
        v_process_id := log_process_func(
            'Loading: dim_time', 
            'dim_time', 
            'STARTED'
        );
        BEGIN
            INSERT INTO dim_time (
                year,
                month,
                day
            )
            SELECT 
                EXTRACT (YEAR FROM TO_DATE(closed_date, 'MM-DD-YYYY')) AS year,
                EXTRACT (MONTH FROM TO_DATE(closed_date, 'MM-DD-YYYY')) AS month,
                EXTRACT (DAY FROM TO_DATE(closed_date, 'MM-DD-YYYY')) AS day
            
            FROM trans_crime_register;

            -- add the rows processed in this step
            v_rows_processed := SQL%ROWCOUNT;

           -- Update process log with success status
           v_process_id := log_process_func(
            'Loading: dim_time', 
            'dim_time', 
            'SUCCESS',
            v_rows_processed,
            NULL,
            v_process_id);

        EXCEPTION
            WHEN OTHERS THEN
                --capture the error message using SQLERRM
                v_error_message:= 'Error Code: ' || SQLCODE || '_' || SQLERRM;
                
                IF NOT log_error_func('N/A', 'dim_time', v_error_message) THEN
                    NULL; -- Or log that error logging itself failed, if needed
                END IF;
                -- Update process log with failure status
                v_process_id := log_process_func(
                    'Loading: dim_time',
                    'dim_time',
                    'FAILED',
                    NULL,
                    v_error_message,
                    v_process_id
                ); 
                RAISE;
        END;
    END load_dim_time;


--------------------------------------------------------------
-- LOAD EXTRA DIM DATA FROM LEEDS (PIVOT_DATA_LEEDS)
--------------------------------------------------------------
PROCEDURE load_from_leeds AS
        v_process_id NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message VARCHAR2(4000);  -- Declare a variable to hold error message
    BEGIN
        -- Log process start
        v_process_id := log_process_func(
            'Loading: dim_from_leeds', 
            'dim_from_leeds', 
            'STARTED'
        );
        BEGIN

            INSERT INTO dim_location(city_name, data_source)
            SELECT DISTINCT
                pdl.neighbourhood,
                'CRIME_DATA_LEEDS'
            FROM pivot_data_leeds pdl WHERE pdl.neighbourhood IS NOT NULL;


           -- Insert into dim_crime_type with properly controlled closure_status
            insert into dim_crime_type(crime_type, closure_status, data_source)
            select distinct 
                pdl.crime_types,
                case
                    when random_value <= 0.9 then 'CLOSED'    -- 90% chance for CLOSED
                    when random_value <= 0.95 then 'OPEN'     -- 5% chance for OPEN
                    else 'ESCALATED'                          -- 5% chance for ESCALATED
                end as closure_status,
                'CRIME_DATA_LEEDS'
            from (
                select 
                    pdl.crime_types,
                    dbms_random.value(0, 1) as random_value  -- Generate random value once per row
                from pivot_data_leeds pdl
            ) pdl;
            
            INSERT INTO dim_officer(full_name, data_source)
            SELECT DISTINCT
                UPPER(pdl.force),
                'CRIME_DATA_LEEDS'
            FROM pivot_data_leeds pdl WHERE pdl.force IS NOT NULL;

            MERGE INTO dim_time c
                USING (
                    SELECT DISTINCT 
                    TO_NUMBER(SUBSTR(pdl.month, 1,4)) AS year,
                    TO_NUMBER(SUBSTR(pdl.month, 6,2)) AS month
                    FROM pivot_data_leeds pdl
                    WHERE pdl.month IS NOT NULL
                    )e
                ON (c.year = e.year AND c.month = e.month)
                WHEN NOT MATCHED THEN
                INSERT (year, month)
                VALUES(e.year, e.month);
                    -- add the rows processed in this step
                v_rows_processed := SQL%ROWCOUNT;

            -- Update process log with success status
            v_process_id := log_process_func(
            'Loading: dim_from_leeds', 
            'dim_from_leeds', 
            'SUCCESS',
            v_rows_processed,
            NULL,
            v_process_id);
                
        EXCEPTION
            WHEN OTHERS THEN
                --capture the error message using SQLERRM
                v_error_message:= 'Error Code: ' || SQLCODE || '_' || SQLERRM;
                
                    IF NOT log_error_func('N/A', 'dim_from_leeds', v_error_message) THEN
                        NULL; -- Or log that error logging itself failed, if needed
                    END IF;
                    -- Update process log with failure status
                    v_process_id := log_process_func(
                        'Loading: dim_from_leeds',
                        'dim_from_leeds',
                        'FAILED',
                        NULL,
                        v_error_message,
                        v_process_id
                    ); 
                    RAISE;
            
        END;
    END load_from_leeds;

--------------------------------------------------------------
-- LOAD FACT TABLE (PRCS + PS_WALES + LEEDS)
--------------------------------------------------------------
PROCEDURE load_fact_table AS
        v_process_id NUMBER;
        v_rows_processed NUMBER := 0;
        v_error_message VARCHAR2(4000);  -- Declare a variable to hold error message
    BEGIN
        -- Log process start
        v_process_id := log_process_func(
            'Loading: fact_closed_crimes', 
            'fact_closed_crimes', 
            'STARTED'
        );
        BEGIN
            MERGE INTO fact_closed_crimes fc
            USING(
                SELECT dt.time_id, dl.location_id, dct.crimetype_id, dpo.officer_id, SUM(total_crimes) AS no_of_crimes
                FROM pivot_data_leeds pdl
                INNER JOIN dim_location dl ON pdl.NEIGHBOURHOOD=dl.city_name
                INNER JOIN dim_crime_type dct ON pdl.crime_types=dct.crime_type
                INNER JOIN dim_officer dpo ON UPPER(pdl.force)=dpo.full_name
                INNER JOIN dim_time dt ON SUBSTR(pdl.month, 1,4)=dt.year AND SUBSTR(pdl.month, 6,2)=dt.month
                -- WHERE dct.closure_status='CLOSED'
                GROUP BY dl.location_id, dpo.officer_id, dct.crimetype_id, dt.time_id
            )s 
            ON(
                fc.time_id=s.time_id AND
                fc.location_id=s.location_id AND
                fc.crimetype_id = s.crimetype_id AND
                fc.officer_id=s.officer_id
            )
            WHEN MATCHED THEN
                UPDATE SET fc.no_of_crimes= fc.no_of_crimes+ s.no_of_crimes
            WHEN NOT MATCHED THEN
                INSERT (time_id, location_id, crimetype_id, officer_id, no_of_crimes)
                VALUES(s.time_id, s.location_id, s.crimetype_id, s.officer_id, s.no_of_crimes);


            MERGE INTO fact_closed_crimes fc
            USING(
                SELECT dt.time_id, dl.location_id, dct.crimetype_id, dpo.officer_id, COUNT(dct.crimetype_id) AS no_of_crimes
                FROM trans_crime_register tcr
                INNER JOIN dim_crime_type dct ON tcr.fk_crime_type=dct.crime_type_key
                INNER JOIN dim_location dl ON tcr.fk_location = dl.location_key
                INNER JOIN dim_officer dpo ON tcr.fk_police_officer = dpo.officer_key
                INNER JOIN dim_time dt 
                ON TO_CHAR(TO_DATE(tcr.closed_date, 'MM-DD-YYYY'), 'YYYY') = TO_CHAR(dt.year)
                AND TO_CHAR(TO_DATE(tcr.closed_date, 'MM-DD-YYYY'), 'MM') = TO_CHAR(dt.month)
                AND TO_CHAR(TO_DATE(tcr.closed_date, 'MM-DD-YYYY'), 'DD') = TO_CHAR(dt.day)
                -- WHERE dct.closure_status='CLOSED'
                GROUP BY dl.location_id, dpo.officer_id, dct.crimetype_id, dt.time_id
            )s 
            ON(
                fc.time_id=s.time_id AND
                fc.location_id=s.location_id AND
                fc.crimetype_id = s.crimetype_id AND
                fc.officer_id=s.officer_id
            )

            WHEN MATCHED THEN
                UPDATE SET fc.no_of_crimes= fc.no_of_crimes+ s.no_of_crimes
            WHEN NOT MATCHED THEN
                INSERT (time_id, location_id, crimetype_id, officer_id, no_of_crimes)
                VALUES(s.time_id, s.location_id, s.crimetype_id, s.officer_id, s.no_of_crimes);
            -- add the rows processed in this step
            v_rows_processed := SQL%ROWCOUNT;
            
            -- Update process log with success status
            v_process_id := log_process_func(
                'Loading: fact_closed_crimes', 
                'fact_closed_crimes', 
                'SUCCESS',
                v_rows_processed,
                NULL,
                v_process_id);

        EXCEPTION
            WHEN OTHERS THEN
                --capture the error message using SQLERRM
                v_error_message:= 'Error Code: ' || SQLCODE || '_' || SQLERRM;
                
                IF NOT log_error_func('N/A', 'fact_closed_crimes', v_error_message) THEN
                    NULL; -- Or log that error logging itself failed, if needed
                END IF;
                -- Update process log with failure status
                v_process_id := log_process_func(
                    'Loading: fact_closed_crimes',
                    'fact_closed_crimes',
                    'FAILED',
                    NULL,
                    v_error_message,
                    v_process_id
                ); 
                RAISE;
        END;
    END load_fact_table;
END loading_pkg;
/

--------------------------------------------------------------
--EXECUTE THE TRANS PROCEDURE
--------------------------------------------------------------
BEGIN
  loading_pkg.load_dim_location;
  loading_pkg.load_dim_officer;
  loading_pkg.load_dim_crime_type;
  loading_pkg.load_dim_time;
  loading_pkg.load_from_leeds;
  loading_pkg.load_fact_table;
END;
/

/*select * from dim_location;
select * from dim_officer;
select * from dim_crime_type;
select * from dim_time;
select * from fact_closed_Crimes;*/
