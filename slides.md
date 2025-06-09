# Migrating 500M Rows
### From PostgreSQL to ClickHouse

<p class="center"><small>A TheirStack Journey</small></p>

---

## The Scale

- **110 million** jobs
- **5 million** companies  
- **30k** technologies tracked
- **500M+** rows to migrate


--

## Row-based VS column-based DBs

<section class="img_container">
    <img src="./media/row-vs-column-dbs.png">
</section>


---

## PostgreSQL: the struggles

1. Indexing on many columns
2. Index size
3. Updates on all rows
4. Table partitioning
5. RAM needs
6. Arquitecture

--

### Indexing issues

1. 🙂 We add a field
2. 😅 Users want to filter by it
3. 🙄 No indices -> slow queries -> we add an index on that col
4. 😵‍💫 Indices become larger than RAM -> we add more RAM
5. 🤷‍♂️ RAM: 16GB -> 32GB -> 64GB. Barely no improvements

--

### Solution? Partitioning...?

- Jobs table -> `jobs_2024_01, jobs_2024_02, ...`  
<!-- - ![partitioning](./media/partitioning.png) -->

![](./media/db-partitioning.webp)


--

### Partitioning: simple version


Simple version

```sql
ALTER TABLE job RENAME TO job_old;

CREATE TABLE job (LIKE job_old INCLUDING ALL) PARTITION BY RANGE (date_posted);

ALTER TABLE job_old
ADD CONSTRAINT jobs_old CHECK (date_posted BETWEEN '1970-01-01' AND '2024-01-01')

ALTER TABLE job ATTACH PARTITION job_old
FOR VALUES FROM ('1970-01-01') TO ('2024-01-01');

CREATE TABLE public.job_2023_12 PARTITION OF public.job FOR 
    VALUES FROM ('2023-12-01') TO ('2024-01-01');
CREATE TABLE public.job_2024_01 PARTITION OF public.job FOR 
    VALUES FROM ('2024-01-01') TO ('2024-02-01');
...
```
<p class="highlight-yellow">⚠️ Partitions aren't created automatically</p>

--

### Partitioning: gotchas

<blockquote class="small-text">To create a unique or primary key constraint on a partitioned table, the partition keys must not include any expressions or function calls and the constraint's columns must include all of the partition key columns... - <a href="https://www.postgresql.org/docs/current/ddl-partitioning.html#DDL-PARTITIONING-DECLARATIVE-LIMITATIONS">source</a></blockquote>

--

### Partitioning: extra work

Before creating partitions:
1. Drop constraints

And after:
1. Recreate constraints
2. Drop triggers on initial partition
3. Recreate triggers on new table

--

### Partitioning: indices

<p class="highlight-yellow">⚠️ Indices must be created CONCURRENTLY so that reads aren't blocked</p>

Without partitioning

```sql
CREATE INDEX CONCURRENTLY ix_job_easy_apply ON job (easy_apply);
```

With partitioning...

```sql
postgres=# CREATE INDEX CONCURRENTLY ix_job_easy_apply ON job (easy_apply);
ERROR:  cannot create index on partitioned table "job" concurrently
```

--

### Partitioning: indices (2)

<p class="highlight-yellow">⚠️ To be able to create indices concurrently, you need to create them partition by partition</p>

```sql
CREATE INDEX CONCURRENTLY ix_job_easy_apply_2024_02 ON job_2024_01 (easy_apply);
CREATE INDEX CONCURRENTLY ix_job_easy_apply_2024_02 ON job_2024_02 (easy_apply);
CREATE INDEX CONCURRENTLY ix_job_easy_apply_2024_03 ON job_2024_03 (easy_apply);
CREATE INDEX CONCURRENTLY ix_job_easy_apply_2024_04 ON job_2024_04 (easy_apply);
...
CREATE INDEX CONCURRENTLY ix_job_easy_apply_2024_12 ON job_old (easy_apply);
CREATE INDEX CONCURRENTLY ix_job_easy_apply ON job (easy_apply);
```

--

### Partitioning: conclusions

1. Partition by the column most used in queries to reduce data read
2. No free lunch: managing indices will be more annoying, hard to revert
3. If your data keeps growing, the solution likely won't scale


--


### How much data a query reads?

`EXPLAIN (ANALYZE, BUFFERS) ...` is your friend

```sql
-----------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize Aggregate  (cost=158141.07..158141.08 rows=1 width=8) (actual time=37789.355..37792.597 rows=1 loops=1)
   Buffers: shared hit=2998 read=447971 dirtied=4285
   I/O Timings: shared read=185052.710
   ->  Gather  (cost=158140.65..158141.06 rows=4 width=8) (actual time=37717.836..37792.558 rows=5 loops=1)
         Workers Planned: 4
         Workers Launched: 4
         Buffers: shared hit=2998 read=447971 dirtied=4285
         I/O Timings: shared read=185052.710
         ->  Partial Aggregate  (cost=157140.65..157140.66 rows=1 width=8) (actual time=37702.154..37702.163 rows=1 loops=5)
               Buffers: shared hit=2998 read=447971 dirtied=4285
               I/O Timings: shared read=185052.710
               ->  Parallel Append  (cost=0.43..152800.69 rows=1735985 width=0) (actual time=58.178..37619.362 rows=1382171 loops=5)
                     Buffers: shared hit=2998 read=447971 dirtied=4285
                     I/O Timings: shared read=185052.710
                     ->  Parallel Index Only Scan using ix_job_remote on job_old job_1  (cost=0.56..34101.92 rows=649969 width=0) (actual time=65.153..7230.452 rows=2
542574 loops=1)
                           Index Cond: (remote = true)
```

Data read in bytes: (shared hit + read + dirtied) * 8KB (page size) = ...

--

### Materialized views in PostgreSQL

- Large MVs are slow to calculate
- Physical order matters **a lot**
- Order is not respected when you refresh a MV
- Solution: write to normal table instead, recreate each time

```sql
BEGIN;
CREATE TABLE company_technologies_new AS
SELECT technology_id, company_name, count(*) as num_jobs
...
ORDER BY technology_id, company_name;

DROP TABLE IF EXISTS company_technologies_old;
RENAME company_technologies TO company_technologies_old;
RENAME company_technologies_new TO company_technologies;
COMMIT;
```

--

## Row-based

<center><img src="./media/row-based.gif"></center>

--

## Column-based

<center><img src="./media/column-based.gif""></center>


--

## Some ClickHouse peculiarities

Many trade-offs were made to make CH fast:

- No unique constraints
- No primary key as in OLTP DBs
- No row-level indices
- Granules: groups of N rows
- Each insert generates 1 part per partition

--

## ClickHouse tips:

- How data is store in disk matters a lot
- Sorting key: column most used to filter first
- Typically the same column used for partitioning
- Partitions are created automatically
- Inserts can't hit more than 100 partitions -> up to 100 parts created on each insert


--

### Jobs table: first schema design


```sql
CREATE TABLE job_2
(
    `id` UInt32,
    `posted_at` Date,
    `url` String,
    `title` String,
    `description` String,
    ...
    `title_tokenized` Array(String),
    `url_hashed` UInt64,
    ...
)
ENGINE = ReplacingMergeTree(updated_at)
PARTITION BY toYYYYMM(posted_at)
ORDER BY (posted_at, url_hashed)
SAMPLE BY url_hashed
```

--

### Select * where ... don't even try


- <p class="highlight-yellow">Even if you add WHERE and LIMIT clauses, adding large columns to a select query slow it down</p>


```sql
SELECT *
FROM job_2 
WHERE has(title_tokenized, 'kafka') 
ORDER BY posted_at DESC
LIMIT 10
FORMAT NULL
```

- This is an issue known [for](https://github.com/ClickHouse/ClickHouse/issues/7187) [years](https://github.com/ClickHouse/ClickHouse/issues/54977) and [solved recently](https://clickhouse.com/blog/clickhouse-gets-lazier-and-faster-introducing-lazy-materialization) with lazy materialization 🥳

--




--



```sql
SELECT *
FROM job
WHERE true 
    AND has(title_tokenized, 'kafka')
    -- AND company_name = 'Santander'
ORDER BY neg_posted_at_timestamp, url_hashed
LIMIT 100
```

<p class="highlight-red">❌ This won't work - reads more columns than needed</p>

<p class="small-text">PREWHERE optimization theoretically helps, but didn't seem effective in our case</p>

--

### WHERE vs PREWHERE

- **Typical ClickHouse use case:** Analytics
  - Read many rows, few columns
- **Our use case:** Search
  - Read many columns (almost all) from few rows (after filtering many rows by few columns)
- <span class="highlight-red">`SELECT * FROM table WHERE ... ORDER BY ... LIMIT ...` doesn't work</span>
- Fetches all columns first, then filters

--

### Our Query Pattern

```sql
WITH col_idx_1, col_idx_2 AS (
    SELECT col_idx_1, col_idx_2 
    FROM table 
    WHERE col_a = ..., etc 
    ORDER BY col_idx_1, col_idx_2
    LIMIT n
)
, rows_cte AS (
    SELECT *
    FROM table
    WHERE (col_idx_1, col_idx_2) IN (
        SELECT * FROM col_idx_1, col_idx_2
    )
)
SELECT *
FROM rows_cte
ORDER BY col_idx_1, col_idx_2
```

<p class="highlight-green">✅ Two-step approach: filter first, then fetch full rows</p>

---

## ORDER BY Effects
### Schema Design Matters

--

### Query Performance Comparison

```sql
-- ASC Order
SELECT neg_posted_at_timestamp, url_hashed 
FROM job 
WHERE has(title_tokenized, 'snake') 
ORDER BY neg_posted_at_timestamp ASC 
LIMIT 10

-- Result: 4.151 sec, 91.85M rows, 7.01 GB
-- (22.12M rows/s, 1.69 GB/s)
```

```sql
-- DESC Order  
SELECT neg_posted_at_timestamp, url_hashed 
FROM job 
WHERE has(title_tokenized, 'snake') 
ORDER BY neg_posted_at_timestamp DESC 
LIMIT 10

-- Result: 7.073 sec, 91.85M rows, 7.01 GB
-- (12.98M rows/s, 991.73 MB/s)
```

<p class="highlight-yellow">⚠️ Order direction significantly impacts performance</p>

---

## Use Case: Company Filtering

--

### Solution: Company Projections

- Projections are at part level
- 500 parts = 500 projections per part
- **Set index for companies:** <span class="highlight-red">didn't work</span>
- **Materialized View ordered by company:**
  - <span class="highlight-green">More efficient reads (fewer parts)</span>
  - <span class="highlight-red">Harder to manage updates/deletes</span>

---

## To Partition or Not?

--

### ClickHouse Recommendation

- <span class="highlight-yellow">Only use partitioning for data management</span>
- Easier to delete old data

--

### Reality Check

- <span class="highlight-red">Parts > 150GB: ClickHouse won't merge</span>
- Larger parts = harder merges
- More memory and CPU needed
- Balance between part size and merge efficiency

---

## Upserts: The Challenge

--

### FINAL Modifier

- <span class="highlight-red">With production data: unviable</span>
- Performance degrades significantly
- Not suitable for large datasets

--

### ReplacingMergeTree

- <span class="highlight-red">After many days: still had duplicates</span>
- Merge process doesn't guarantee immediate deduplication
- Eventual consistency model

---

## Key Learnings

--

### PostgreSQL ➜ ClickHouse

<div style="display: flex; justify-content: space-between;">
    <div style="width: 45%;">
        <h4 class="highlight-red">PostgreSQL Challenges</h4>
        <ul class="small-text">
            <li>Index management complexity</li>
            <li>Update performance issues</li>
            <li>Memory requirements</li>
            <li>Maintenance overhead</li>
        </ul>
    </div>
    <div style="width: 45%;">
        <h4 class="highlight-green">ClickHouse Benefits</h4>
        <ul class="small-text">
            <li>Better analytical performance</li>
            <li>Efficient column storage</li>
            <li>Faster materialized views</li>
            <li>Better resource utilization</li>
        </ul>
    </div>
</div>

--

### Query Pattern Adaptation

- Traditional OLTP patterns don't work
- Two-step queries: filter then fetch
- Schema design impacts performance significantly
- Understanding part-level operations is crucial

--

### Trade-offs

- **Upserts:** <span class="highlight-red">Complex in ClickHouse</span>
- **Real-time updates:** <span class="highlight-red">Not ClickHouse's strength</span>
- **Analytics:** <span class="highlight-green">ClickHouse excels</span>
- **Large-scale reads:** <span class="highlight-green">Much better performance</span>

---

## Conclusion

- <span class="highlight-green">Migration successful for analytical workloads</span>
- Query patterns required significant adaptation
- Hardware requirements more predictable
- Better suited for TheirStack's scale and use case

<br>

<p class="center"><strong>500M rows migrated, lessons learned! 🚀</strong></p>

---

# Questions?

<p class="center"><small>Thank you!</small></p> 