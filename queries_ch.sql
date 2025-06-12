-- @block
SELECT id
FROM job 
WHERE has(title_tokenized, 'kafka') 
ORDER BY neg_posted_at_timestamp, url_hashed
LIMIT 100
FORMAT NULL


-- @block
EXPLAIN actions=1
SELECT 
title, posted_at
, description, description_cleaned
FROM job 
WHERE
    TRUE
    AND has(title_tokenized, 'kafka') 
    AND neg_posted_at_timestamp BETWEEN -toUnixTimestamp(now()) AND -toUnixTimestamp(now() - INTERVAL 1 MONTH)
ORDER BY neg_posted_at_timestamp, url_hashed
LIMIT 100
-- FORMAT NULL
SETTINGS query_plan_optimize_lazy_materialization = true
-- FORMAT Vertical
FORMAT PrettySpaceNoEscapesMonoBlock


-- @block
select 
    id,
    posted_at,
    date_reposted,
    discovered_at,
    reposted,
    updated_at,
    source_url,
    url,
    title,
    description,
    description_cleaned,
    company_id,
    company_name,
    country_codes,
    location,
    short_location,
    long_location,
    state_code,
    postal_code,
    latitude,
    longitude,
    workplace_types,
    seniority,
    min_annual_salary_usd,
    max_annual_salary_usd,
    min_annual_salary,
    max_annual_salary,
    salary_currency,
    salary_string,
    scraper_name,
    employment_statuses,
    title_tokenized,
    url_hashed,
    neg_posted_at_timestamp,
    easy_apply,
    original_job_dict,
    search_metadata,
    company_key,
    company_name_shown,
    min_equity,
    max_equity,
    linkedin_json,
    keyword_slugs_description,
    keyword_slugs_title,
    keyword_slugs_url,
    keyword_slugs,
    created_at
FROM job
WHERE
    TRUE
    AND has(title_tokenized, 'kafka') 
    AND neg_posted_at_timestamp BETWEEN -toUnixTimestamp(now()) AND -toUnixTimestamp(now() - INTERVAL 1 MONTH)
ORDER BY neg_posted_at_timestamp, url_hashed
LIMIT 100
-- FORMAT NULL
SETTINGS
    optimize_move_to_prewhere = true,
    query_plan_optimize_lazy_materialization = true;



-- @block
WITH rows_cte AS (
    SELECT neg_posted_at_timestamp, url_hashed
    FROM job
    WHERE has(title_tokenized, 'kafka')
        AND neg_posted_at_timestamp BETWEEN -toUnixTimestamp(now()) AND -toUnixTimestamp(now() - INTERVAL 1 MONTH)
    ORDER BY neg_posted_at_timestamp, url_hashed
    LIMIT 100
), filtered_rows AS (
    SELECT * FROM job
    WHERE (neg_posted_at_timestamp, url_hashed) IN (
        SELECT neg_posted_at_timestamp, url_hashed FROM rows_cte
    )
)
SELECT * FROM filtered_rows
ORDER BY neg_posted_at_timestamp, url_hashed
FORMAT NULL



-- @block
-- select * is too slow, even with filters
SELECT *
FROM job
WHERE true 
    AND has(title_tokenized, 'kafka')
    -- AND company_name = 'Santander'
ORDER BY neg_posted_at_timestamp, url_hashed
LIMIT 100
FORMAT NULL

-- @block
-- prewhere has no effect
SELECT *
FROM job
PREWHERE true 
    AND has(title_tokenized, 'kafka')
    -- AND company_name = 'Santander'
ORDER BY neg_posted_at_timestamp, url_hashed
LIMIT 100
FORMAT NULL


-- @block
-- getting only a few columns is fast
SELECT posted_at, url_hashed, title
FROM job_2 
WHERE has(title_tokenized, 'kafka') 
ORDER BY posted_at ASC 
LIMIT 10
FORMAT NULL


-- @block
SELECT posted_at, url_hashed, title
FROM job
WHERE true 
    AND match(title, 'kafka')
ORDER BY neg_posted_at_timestamp, url_hashed
LIMIT 100
FORMAT NULL

-- @block
SELECT posted_at, url_hashed, title
FROM job_2 
WHERE has(title_tokenized, 'snake') 
ORDER BY posted_at ASC
LIMIT 100
FORMAT NULL

-- @block
SELECT posted_at, url_hashed, title
FROM job_2 
WHERE has(title_tokenized, 'snake') 
ORDER BY posted_at DESC
LIMIT 100
FORMAT NULL

-- @block
SELECT
    neg_posted_at_timestamp,
    url_hashed,
    title
FROM job
WHERE company_name = 'Tinybird'
ORDER BY neg_posted_at_timestamp, url_hashed
LIMIT 100
-- FORMAT NULL
SETTINGS optimize_use_projections=0


-- @block
EXPLAIN indexes=1
SELECT
    posted_at,
    source_url,
    company_name
FROM job_2
WHERE company_name = 'Apple'
ORDER BY posted_at
LIMIT 100
-- FORMAT NULL
SETTINGS
    -- ignore_data_skipping_indices='idx_company_name',
    optimize_read_in_order=0
    optimize_use_projections=1,
    force_optimize_projection=1
    -- optimize_read_in_order=0


-- @block
show create table job_2 FORMAT Vertical


-- @block
SELECT *
FROm company_keyword
WHERE company_name = 'Apple'
FORMAT NULL
SETTINGS optimize_use_projections=0

-- @block
SELECT *
FROm company_keyword
WHERE company_name = 'Apple'
FORMAT NULL
SETTINGS optimize_use_projections=1

-- @block
show create table job FORMAT Vertical


-- @block
SELECT 
    neg_posted_at_timestamp
    , url_hashed
    , company_name
FROM job
WHERE company_name = 'Apple'
ORDER BY
    neg_posted_at_timestamp,
    url_hashed
LIMIT 0, 10
SETTINGS max_threads=10


-- @block
SELECT *
FROM company_keyword
WHERE company_name = 'Apple'
-- ORDER BY keyword_slug, confidence
FORMAT `NULL`



-- @block
SELECT 
    neg_posted_at_timestamp
    , url_hashed
    , company_name 
FROM job
WHERE company_name = 'Apple'
ORDER BY
    -- neg_posted_at_timestamp,
    url_hashed
LIMIT 0, 10
SETTINGS
    max_threads=10
    , optimize_read_in_order=0
    , optimize_use_projections=1


-- @block
select title, company_name, posted_at
from job sample 0.01
where company_name in ('Apple', 'Google', 'Amazon', 'Microsoft', 'Meta')
order by posted_at desc, title
limit 10 by company_name
limit 50
INTO OUTFILE 'sample_jobs.csv' TRUNCATE
FORMAT CSVWithNames


-- @block
select title, company, posted_at
from job
where company_name in ('Apple', 'Google', 'Amazon', 'Microsoft')
order by posted_at desc
limit 100