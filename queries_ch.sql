-- block
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


SELECT posted_at, url_hashed, title
FROM job_2 
WHERE has(title_tokenized, 'kafka') 
ORDER BY posted_at DESC
LIMIT 10
FORMAT NULL

-- @block
-- but if we get the elements in the sorting key first, it's fast

