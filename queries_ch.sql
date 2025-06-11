-- @block
SELECT id
FROM job 
WHERE has(title_tokenized, 'kafka') 
ORDER BY neg_posted_at_timestamp, url_hashed
LIMIT 100
FORMAT NULL


-- @block
SELECT *
FROM job 
WHERE
    TRUE
    AND has(title_tokenized, 'kafka') 
    AND neg_posted_at_timestamp BETWEEN -toUnixTimestamp(now()) AND -toUnixTimestamp(now() - INTERVAL 1 MONTH)
ORDER BY neg_posted_at_timestamp, url_hashed
LIMIT 100
FORMAT NULL


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
SELECT
    neg_posted_at_timestamp,
    url_hashed,
    title
FROM job
WHERE company_name = 'Apple'
ORDER BY neg_posted_at_timestamp, url_hashed
LIMIT 100
-- FORMAT NULL
-- SETTINGS
    -- optimize_read_in_order=0,
    -- optimize_use_projections=1,
    -- optimize_read_in_order=0



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