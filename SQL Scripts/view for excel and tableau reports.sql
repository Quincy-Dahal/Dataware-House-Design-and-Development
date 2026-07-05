CREATE OR REPLACE VIEW view_all_crimes_data AS
SELECT
    fc.crime_key,
    fc.no_of_crimes,
    dt.time_id,
    dt.year,
    dt.month,
    dt.day,
    dl.location_id,
    dl.location_key,
    dl.region_name,
    dl.street_name,
    dl.post_code,
    dl.city_name,
    dl.data_source AS location_data_source,
    dct.crimetype_id,
    dct.crime_type_key,
    dct.closure_status,
    dct.crime_type,
    dct.data_source AS crime_type_data_source,
    do.officer_id,
    do.officer_key,
    do.full_name AS force,
    do.department,
     CASE
    WHEN do.rank IS NULL THEN
        FLOOR(MOD(ABS(ORA_HASH(TO_CHAR(do.officer_id))), 10) + 1)
    ELSE TO_NUMBER(do.rank)
END AS rank,
    do.data_source AS officer_data_source
FROM
    fact_closed_crimes fc
JOIN
    dim_time dt ON fc.time_id = dt.time_id
JOIN
    dim_location dl ON fc.location_id = dl.location_id
JOIN
    dim_crime_type dct ON fc.crimetype_id = dct.crimetype_id
JOIN
    dim_officer do ON fc.officer_id = do.officer_id
