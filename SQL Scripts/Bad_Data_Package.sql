--------------------------------------------------------------
-- BAD DATA IDENTIFICATION (FINAL SINGLE FILE)
--------------------------------------------------------------

--------------------------------------------------------------
-- RESET BAD DATA TABLES
--------------------------------------------------------------
DROP TABLE location_bad_data;
DROP TABLE police_officer_bad_data;

--------------------------------------------------------------
-- CREATE BAD DATA TABLES
--------------------------------------------------------------

-- Bad data table for LOCATION
CREATE TABLE location_bad_data AS
SELECT *
FROM stg_location
WHERE 1 = 0;

-- Bad data table for OFFICER
CREATE TABLE police_officer_bad_data AS
SELECT *
FROM stg_officer
WHERE 1 = 0;

--------------------------------------------------------------
-- PACKAGE SPECIFICATION
--------------------------------------------------------------
CREATE OR REPLACE PACKAGE bad_data_pkg AS
  PROCEDURE identify_location_bad_data;
  PROCEDURE identify_officer_bad_data;
END bad_data_pkg;
/
--------------------------------------------------------------
-- PACKAGE BODY
--------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY bad_data_pkg AS

  ------------------------------------------------------------------
  -- PRIVATE FUNCTION: PROCESS LOG
  ------------------------------------------------------------------
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
      ELSE
          UPDATE process_log
          SET end_time = CURRENT_TIMESTAMP,
              rows_processed = p_rows_processed,
              status = p_status,
              error_message = p_error_message
          WHERE process_id = v_process_id;
      END IF;

      RETURN v_process_id;
  END log_process_func;

  ------------------------------------------------------------------
  -- PRIVATE FUNCTION: ERROR LOG
  ------------------------------------------------------------------
  FUNCTION log_error_func (
      p_data_source   IN VARCHAR2,
      p_target_table  IN VARCHAR2,
      p_error_message IN VARCHAR2
  )
  RETURN BOOLEAN
  IS
  BEGIN
      INSERT INTO error_log (error_timestamp, data_source, target_table, error_message)
      VALUES (CURRENT_TIMESTAMP, p_data_source, p_target_table, p_error_message);
      RETURN TRUE;
  EXCEPTION
      WHEN OTHERS THEN
          RETURN FALSE;
  END log_error_func;

  ------------------------------------------------------------------
  -- IDENTIFY LOCATION BAD DATA
  ------------------------------------------------------------------
  PROCEDURE identify_location_bad_data AS
      v_process_id     NUMBER;
      v_rows_processed NUMBER := 0;
      v_error_message  VARCHAR2(4000);
  BEGIN
      v_process_id := log_process_func(
          'bad_data: location_bad_data',
          'location_bad_data',
          'STARTED'
      );

      BEGIN
          INSERT INTO location_bad_data
          SELECT *
          FROM stg_location
          WHERE location_key IS NULL
             OR region_name IS NULL
             OR street_name IS NULL
             OR post_code IS NULL
             OR city_name IS NULL
             OR REGEXP_LIKE(region_name, '^[0-9]+$')
             OR REGEXP_LIKE(city_name, '^[0-9]+$')
             OR NOT (
                    REGEXP_LIKE(TRIM(region_name), '^[a-z]+( [a-z]+)*$')
                 OR REGEXP_LIKE(TRIM(region_name), '^[A-Z]+( [A-Z]+)*$')
                 OR REGEXP_LIKE(
                        TRIM(region_name),
                        '^[A-Z][a-z]*( [A-Z][a-z]*)*(, [A-Z][a-z]*)*$'
                    )
             )
             OR NOT (
                    REGEXP_LIKE(TRIM(city_name), '^[a-z]+( [a-z]+)*$')
                 OR REGEXP_LIKE(TRIM(city_name), '^[A-Z]+( [A-Z]+)*$')
                 OR REGEXP_LIKE(
                        TRIM(city_name),
                        '^[A-Z][a-z]*( [A-Z][a-z]*)*$'
                    )
             );

          v_rows_processed := SQL%ROWCOUNT;

          v_process_id := log_process_func(
              'bad_data: location_bad_data',
              'location_bad_data',
              'SUCCESS',
              v_rows_processed,
              p_process_id => v_process_id
          );

      EXCEPTION
          WHEN OTHERS THEN
              v_error_message := 'Error Code: ' || SQLCODE || '_' || SQLERRM;

              IF NOT log_error_func('N/A', 'location_bad_data', v_error_message) THEN
                  NULL;
              END IF;

              v_process_id := log_process_func(
                  'bad_data: location_bad_data',
                  'location_bad_data',
                  'FAILED',
                  p_error_message => v_error_message,
                  p_process_id => v_process_id
              );

              ROLLBACK;
              RAISE;
      END;
  END identify_location_bad_data;

  ------------------------------------------------------------------
  -- IDENTIFY OFFICER BAD DATA
  ------------------------------------------------------------------
  PROCEDURE identify_officer_bad_data AS
      v_process_id     NUMBER;
      v_rows_processed NUMBER := 0;
      v_error_message  VARCHAR2(4000);
  BEGIN
      v_process_id := log_process_func(
          'bad_data: police_officer_bad_data',
          'police_officer_bad_data',
          'STARTED'
      );

      BEGIN
          INSERT INTO police_officer_bad_data
          SELECT *
          FROM stg_officer
          WHERE officer_key IS NULL
             OR full_name IS NULL
             OR department IS NULL
             OR rank IS NULL
             OR REGEXP_LIKE(full_name, '^[0-9]+$')
             OR REGEXP_LIKE(department, '^[0-9]+$')
             OR NOT (
                    REGEXP_LIKE(TRIM(full_name), '^[a-z]+( [a-z]+)*$')
                 OR REGEXP_LIKE(TRIM(full_name), '^[A-Z]+( [A-Z]+)*$')
                 OR REGEXP_LIKE(
                        TRIM(full_name),
                        '^[A-Z][a-z]*( [A-Z][a-z]*)*$'
                    )
             )
             OR NOT (
                    REGEXP_LIKE(TRIM(department), '^[a-z]+( [a-z]+)*$')
                 OR REGEXP_LIKE(TRIM(department), '^[A-Z]+( [A-Z]+)*$')
                 OR REGEXP_LIKE(
                        TRIM(department),
                        '^[A-Z][a-z]*( [A-Z][a-z]*)*$'
                    )
             );

          v_rows_processed := SQL%ROWCOUNT;

          v_process_id := log_process_func(
              'bad_data: police_officer_bad_data',
              'police_officer_bad_data',
              'SUCCESS',
              v_rows_processed,
              p_process_id => v_process_id
          );

      EXCEPTION
          WHEN OTHERS THEN
              v_error_message := 'Error Code: ' || SQLCODE || '_' || SQLERRM;

              IF NOT log_error_func('N/A', 'police_officer_bad_data', v_error_message) THEN
                  NULL;
              END IF;

              v_process_id := log_process_func(
                  'bad_data: police_officer_bad_data',
                  'police_officer_bad_data',
                  'FAILED',
                  p_error_message => v_error_message,
                  p_process_id => v_process_id
              );

              ROLLBACK;
              RAISE;
      END;
  END identify_officer_bad_data;

END bad_data_pkg;
/
--------------------------------------------------------------
-- EXECUTE BAD DATA IDENTIFICATION
--------------------------------------------------------------
BEGIN
   bad_data_pkg.identify_location_bad_data;
   bad_data_pkg.identify_officer_bad_data;
END;
/
--------------------------------------------------------------
-- VERIFY RESULTS
--------------------------------------------------------------
/*SELECT * FROM location_bad_data;
SELECT * FROM police_officer_bad_data;*/
