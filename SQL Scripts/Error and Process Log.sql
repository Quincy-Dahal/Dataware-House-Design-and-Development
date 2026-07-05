--------------------------------------------------------------
-- 1. DROP EXISTING OBJECTS 
--------------------------------------------------------------

DROP TRIGGER error_log_trig;
DROP TRIGGER process_log_trig;

DROP TABLE error_log;
DROP TABLE process_log;

DROP SEQUENCE error_log_seq;
DROP SEQUENCE process_log_seq;


--------------------------------------------------------------
-- 2. CREATE SEQUENCES
--------------------------------------------------------------

CREATE SEQUENCE error_log_seq
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

CREATE SEQUENCE process_log_seq
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;


--------------------------------------------------------------
-- 3. CREATE TABLES
--------------------------------------------------------------

-- Process-level log: one row per ETL run / procedure execution
CREATE TABLE process_log (
    process_id      NUMBER PRIMARY KEY,
    process_name    VARCHAR2(100),
    target_table    VARCHAR2(50),
    start_time      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time        TIMESTAMP,
    rows_processed  NUMBER,
    status          VARCHAR2(20),       -- 'RUNNING', 'SUCCESS', 'FAILED'
    error_message   VARCHAR2(4000)      
);

-- Row-level error log
CREATE TABLE error_log (
    error_id        NUMBER PRIMARY KEY,
    process_id      NUMBER,             -- links back to process_log
    error_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_source     VARCHAR2(50),       -- 'PRCS', 'PS_WALES'
    target_table    VARCHAR2(50),       --  'STG_OFFICER'
    error_message   VARCHAR2(4000),
    CONSTRAINT fk_error_log_process
        FOREIGN KEY (process_id)
        REFERENCES process_log(process_id)
);


--------------------------------------------------------------
-- 4. CREATE TRIGGERS TO AUTO-ASSIGN IDS
--------------------------------------------------------------

-- Process log trigger
CREATE OR REPLACE TRIGGER process_log_trig
BEFORE INSERT ON process_log
FOR EACH ROW
BEGIN
    IF :NEW.process_id IS NULL THEN
        SELECT process_log_seq.NEXTVAL
        INTO   :NEW.process_id
        FROM   dual;
    END IF;
END;
/
 
-- Error log trigger
CREATE OR REPLACE TRIGGER error_log_trig
BEFORE INSERT ON error_log
FOR EACH ROW
BEGIN
    IF :NEW.error_id IS NULL THEN
        SELECT error_log_seq.NEXTVAL
        INTO   :NEW.error_id
        FROM   dual;
    END IF;
END;
/
