Skip to:

Skip to Jira Navigation
Skip to Side Navigation
Skip to Main Content

Custom Jira logo

Your work

Projects

Filters

Dashboards

Teams

Plans
Assets

Apps

Create
Search

Chat

9+




Garda MS FF 6 Postgres SQL DB Operate
Service project
Queues
Starred
Select the star icon next to your queues to add them here.
Priority group
Stay on top of what’s important to your team.

All queues
You're in a company-managed project


Back

Add parent

GARDADBO6PGS-588


Research Daily Bulk Query Performance Issue

Create subtask

Link issue


Add Tempo to plan and track time

SLA Panel

Dylan Richards
raised this request
via
Portal

Hide details
View request in portal
Priority



Medium
Description

We have noticed a performance issue when performing a bulk select on our research.daily table.

The goal is to query SELECT d.symbol, d."source", d.field, d."date", d.value FROM research.daily for a list of symbol, source, fields.

It’s currently being done by loading the list we want into a temp table and joining research daily to the temp table.

It is happening in both prod and dev.

test_query.sql - creates a temp table and populates it. it also contains the explain query

dev_slow_query_plan.json - running test_query.sql on gcpdsg01@gcpapp05lhc.

dev_fast_query_plan.json - running the explain plan again yields normal execution times

prod_slow_query_plan.json - running test_query.sql on gcppsg01@gcpapp05p.

prod_fast_query_plan.json - running the explain plan again yields normal execution times



explain (ANALYZE, COSTS, VERBOSE, BUFFERS, FORMAT JSON) SELECT d.symbol, d."source" , d.field, d."date", d.value FROM research.daily d JOIN pg_temp.dailybulkselecttemp t ON t."symbol" = d."symbol" and t."source" = d."source" and t."field" = d."field" WHERE d."date" BETWEEN '2015-01-25' and '2025-01-25';
Can you please analyze, find the cause, and offer a solution?

Action Plan


None
Attachments
5

Open prod_slow_queryplan.json
prod_slow_queryplan.json
20 Feb 2025, 02:56 am

Open dev_fast_queryplan.json
dev_fast_queryplan.json
20 Feb 2025, 02:56 am

Open dev_slow_queryplan.json
dev_slow_queryplan.json
20 Feb 2025, 02:56 am

Open test_query.sql
test_query.sql
test_query.sql
20 Feb 2025, 02:56 am

Open prod_fast_queryplan.json
prod_fast_queryplan.json
20 Feb 2025, 02:56 am

Similar requests

Tempo

SLA Panel

Activity
Show:

All

Comments

History

Worklogs

Salesforce Comments

SLA History

Approvals

Summarize

Newest first


Add internal note
 / 
Reply to customer

Pro tip: press 
M
 to comment

Matt Pearson 
28 February 2025 at 22:14

The explain plans are the same on both dev and prod.  Assuming the parameters are the same i.e. the data being retrieved is the same (which is the case based upon the SQL supplied)  The times reflect the difference in when they were run and if the blocks were present in the buffer.

Therefore, either the explain is OK and we need to try to reduce the amount of noise i.e. run it under optimal conditions or the explain plan needs to be changed so it completes in a better time on both runs i.e. it uses the same explain and gets similar times.

Updating the stats might help but the optimiser is picking the same explain plan which is probably good.  Therefore, we may need to see what we can do to run some of these together.

For instance, we have 10 years.  Could we process these say in yearly intervals but maybe 2 or 3 at a time.

I think we need to look at a few potential options:

Run this as Parallel queries and run it when the load is low.

Change the query, so it runs the same query but in sequence to ensure that each read of the tables is not interfering with the other reads and UNION it and the end.

Preload the buffer i.e. SELECT into the buffer before doing any UPDATE operations i.e. do SELECT * FROM [chuck] before running UPDATE [chunk] SET …

The last suggestion is bad but we have seen preloading the buffer with the needed pages can help UPDATE performance.

Extended statistics might help but if the explain plan is already optimised, then adding more stats on the non-indexed columns won’t help.  If we are looking for another explain plan (like the parallel option), then creating additional stats might help.

All options would need to be explored.  

In terms of most likely outcome, setting the query to use parallel scans offers the best return, IMO.


Edit

Delete


KueLeong.Yeo@gardacp.com 
28 February 2025 at 07:52

the slow run is recently discovered



Walton Njei Ayang 
27 February 2025 at 22:00
Edited

Reviewing the query in dev we can I identify the following:

The slow run has an execution time of 78 seconds and the fast run has an execution time of 1sec.

For the fast run, the planning time 7.7ms and the slow run is 84.79ms but it is a tiny fraction of the execution time so is not the main issue. This is an indication of may be stale stats, checking the research.daily table and its chunks most of the chunks have staled stats as indicated below. We would recommend running an analyze on this hypertable to get updated stats.



     chunk_schema      |      chunk_name      |   relid    | seq_scan | seq_tup_read |  idx_scan  | idx_tup_fetch | n_tup_ins | n_tup_upd | n_tup_del | n_live_tup | n_dead_tup | last_
vacuum |        last_autovacuum        | vacuum_count | autovacuum_count | last_analyze |       last_autoanalyze
-----------------------+----------------------+------------+----------+--------------+------------+---------------+-----------+-----------+-----------+------------+------------+------
-------+-------------------------------+--------------+------------------+--------------+-------------------------------
 _timescaledb_internal | _hyper_1_28834_chunk |  993813507 |       16 |    108120610 |    2522672 |        225482 |    206816 |         2 |         0 |  104934570 |          3 |
       | 2025-02-12 10:07:08.400304+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28835_chunk |  993835605 |        1 |    116907206 |    2520574 |        241096 |    196874 |         0 |         0 |     196874 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28837_chunk |  993856812 |        1 |    122131653 |    2543984 |        491316 |    198317 |         0 |         0 |  123417033 |          0 |
       | 2025-02-24 00:16:51.206664+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28838_chunk |  993878915 |        1 |    148117715 |    2586040 |       1640643 |    225677 |         0 |         0 |     225677 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28839_chunk |  993907290 |        1 |    102485718 |    2506416 |             0 |         0 |         0 |         0 |   98871033 |          0 |
       | 2025-02-23 09:29:27.528772+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28840_chunk |  993927281 |        1 |    102295091 |    2512500 |       3972979 |     71300 |         0 |         0 |   98537930 |          0 |
       | 2025-02-23 09:28:50.747291+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28841_chunk |  993947769 |        1 |    102863163 |    2596847 |        170046 |    204616 |         0 |         0 |  102357289 |          0 |
       | 2025-02-24 00:15:51.838934+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28842_chunk |  993967606 |        1 |    104784222 |    2512117 |        214121 |    206006 |         0 |         0 |  104161772 |          0 |
       | 2025-02-24 00:16:56.274051+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28843_chunk |  993987709 |        1 |      1385164 |    2505109 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28844_chunk |  993987938 |        1 |      1154438 |    2505221 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28845_chunk |  993987949 |        1 |      4299652 |    2505109 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28846_chunk |  993988768 |        1 |      5784976 |    2505109 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28847_chunk |  993989599 |        1 |      6548505 |    2505109 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28848_chunk |  993990420 |        1 |      7253702 |    2505109 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28849_chunk |  993991653 |        1 |      9155288 |    2505109 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28850_chunk |  993993239 |        1 |      7712062 |    2505109 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28851_chunk |  993994261 |        1 |     10289433 |    2505109 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28852_chunk |  993995874 |        1 |     11153012 |    2505109 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28853_chunk |  993997811 |        1 |     11825966 |    2505109 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28854_chunk |  993999486 |        1 |     12760514 |    2505109 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28855_chunk |  994001529 |        1 |     15054574 |    2505165 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28856_chunk |  994003942 |        1 |     16992743 |    2505189 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28857_chunk |  994006797 |        1 |     19100305 |    2505189 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28858_chunk |  994009666 |        1 |     20518786 |    2505189 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28859_chunk |  994012925 |        1 |     25281516 |    2505189 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28860_chunk |  994017002 |        1 |     23171670 |    2505189 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28861_chunk |  994020821 |        1 |     31482871 |    2505189 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28862_chunk |  994026176 |        1 |     28161601 |    2505189 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28863_chunk |  994030880 |        1 |     35098213 |    2505189 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28864_chunk |  994037119 |        1 |     42706309 |    2505189 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28865_chunk |  994044899 |        1 |     52236130 |    2505189 |             0 |         0 |         0 |         0 |   49500233 |          0 |
       | 2025-02-24 00:09:45.062402+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28866_chunk |  994055182 |        1 |     68773410 |    2505189 |             0 |         0 |         0 |         0 |   66608468 |          0 |
       | 2025-02-24 00:14:26.418054+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28867_chunk |  994069991 |        1 |     91228831 |    2506374 |             0 |         0 |         0 |         0 |   89901095 |          0 |
       | 2025-02-23 09:29:22.157151+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28868_chunk |  994088735 |        1 |     96419111 |    2505740 |             0 |         0 |         0 |         0 |   94902617 |          0 |
       | 2025-02-23 09:29:37.263426+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28869_chunk |  994108630 |        1 |       569958 |    2505109 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28870_chunk |  994108641 |        1 |       636466 |    2505109 |             0 |         0 |         0 |         0 |          0 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28871_chunk |  994108652 |        1 |       330977 |    2505109 |             0 |         0 |         0 |         0 |     329455 |          0 |
       | 2025-02-24 01:36:50.866082+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28872_chunk |  994108663 |        1 |       307361 |    2504997 |             0 |         0 |         0 |         0 |     304443 |          0 |
       | 2025-02-24 01:38:25.98462+00  |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28873_chunk |  994108674 |        1 |        38925 |    2504997 |             0 |         0 |         0 |         0 |      37848 |          0 |
       | 2025-02-24 01:38:41.1041+00   |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28874_chunk |  994108685 |        1 |       133383 |    2504997 |             0 |         0 |         0 |         0 |     129801 |          0 |
       | 2025-02-24 01:38:41.118054+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28875_chunk |  994108696 |        1 |       133902 |    2504997 |             0 |         0 |         0 |         0 |     130249 |          0 |
       | 2025-02-24 01:38:56.228049+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28876_chunk |  994108707 |        1 |       132864 |    2504997 |             0 |         0 |         0 |         0 |     129278 |          0 |
       | 2025-02-24 01:39:41.243758+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28877_chunk |  994108718 |        1 |       133902 |    2504997 |             0 |         0 |         0 |         0 |     130323 |          0 |
       | 2025-02-24 01:39:41.259139+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28878_chunk |  994108753 |        1 |       132864 |    2504997 |             0 |         0 |         0 |         0 |     129014 |          0 |
       | 2025-02-24 01:39:46.447055+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28879_chunk |  994108776 |        1 |       133902 |    2504997 |             0 |         0 |         0 |         0 |     129773 |          0 |
       | 2025-02-24 01:39:56.464252+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28880_chunk |  994108787 |        1 |       133383 |    2504997 |             0 |         0 |         0 |         0 |     129819 |          0 |
       | 2025-02-24 01:39:41.274461+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28881_chunk |  994108863 |        1 |       133383 |    2504997 |             0 |         0 |         0 |         0 |     129827 |          0 |
       | 2025-02-24 01:42:26.711064+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28882_chunk |  994108945 |        1 |       133902 |    2504997 |             0 |         0 |         0 |         0 |     130213 |          0 |
       | 2025-02-24 01:39:56.481305+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28883_chunk |  994109036 |        1 |       144409 |    2504997 |             0 |         0 |         0 |         0 |     140993 |          0 |
       | 2025-02-24 01:39:56.499084+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28884_chunk |  994109103 |        1 |       152753 |    2504997 |             0 |         0 |         0 |         0 |     149557 |          0 |
       | 2025-02-24 01:40:11.554598+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28885_chunk |  994109162 |        1 |       154540 |    2504997 |             0 |         0 |         0 |         0 |     151450 |          0 |
       | 2025-02-24 01:40:11.569649+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28886_chunk |  994109197 |        1 |       157598 |    2504997 |             0 |         0 |         0 |         0 |     154578 |          0 |
       | 2025-02-24 01:40:56.580159+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28887_chunk |  994109234 |        1 |       159255 |    2504997 |             0 |         0 |         0 |         0 |     155972 |          0 |
       | 2025-02-24 01:41:51.654886+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28888_chunk |  994109245 |        1 |       159097 |    2504997 |             0 |         0 |         0 |         0 |     156003 |          0 |
       | 2025-02-24 01:42:31.820324+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28889_chunk |  994109256 |        1 |       162384 |    2504997 |             0 |         0 |         0 |         0 |     159105 |          0 |
       | 2025-02-24 01:42:31.834366+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28890_chunk |  994109267 |        1 |       162441 |    2504997 |             0 |         0 |         0 |         0 |     159187 |          0 |
       | 2025-02-24 01:42:36.834341+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28891_chunk |  994109278 |        1 |       164355 |    2504997 |             0 |         0 |         0 |         0 |     161300 |          0 |
       | 2025-02-24 01:42:36.848827+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28892_chunk |  994109289 |        1 |       163037 |    2504997 |             0 |         0 |         0 |         0 |     159956 |          0 |
       | 2025-02-24 01:42:36.862752+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28893_chunk |  994109300 |        1 |       165716 |    2504997 |             0 |         0 |         0 |         0 |     162625 |          0 |
       | 2025-02-24 01:42:36.876866+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28894_chunk |  994109319 |        1 |       167959 |    2504997 |             0 |         0 |         0 |         0 |     165000 |          0 |
       | 2025-02-24 01:43:46.929807+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28895_chunk |  994109330 |        1 |       169910 |    2504997 |             0 |         0 |         0 |         0 |     166825 |          0 |
       | 2025-02-24 01:44:31.951353+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28896_chunk |  994109341 |        1 |       187447 |    2504997 |             0 |         0 |         0 |         0 |     184665 |          0 |
       | 2025-02-24 01:45:42.048785+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28897_chunk |  994109352 |        1 |       192504 |    2504997 |             0 |         0 |         0 |         0 |     189835 |          0 |
       | 2025-02-23 09:08:41.760096+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28898_chunk |  994109363 |        1 |       192832 |    2504997 |             0 |         0 |         0 |         0 |     190235 |          0 |
       | 2025-02-23 09:08:41.779058+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28899_chunk |  994109374 |        1 |       197385 |    2504997 |             0 |         0 |         0 |         0 |     194743 |          0 |
       | 2025-02-23 09:08:41.798792+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28900_chunk |  994109385 |        1 |       206740 |    2504997 |             0 |         0 |         0 |         0 |     205357 |          0 |
       | 2025-02-24 01:46:42.173264+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28901_chunk |  994109396 |        1 |       211504 |    2504997 |             0 |         0 |         0 |         0 |     210192 |          0 |
       | 2025-02-24 01:46:42.190233+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28902_chunk |  994109407 |        1 |       216099 |    2504997 |             0 |         0 |         0 |         0 |     214929 |          0 |
       | 2025-02-24 01:46:42.205514+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28903_chunk |  994109448 |        1 |       213614 |    2504997 |             0 |         0 |         0 |         0 |     212293 |          0 |
       | 2025-02-24 01:48:32.289107+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28904_chunk |  994109465 |        1 |       214806 |    2504997 |             0 |         0 |         0 |         0 |     213407 |          0 |
       | 2025-02-24 01:48:32.305129+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28905_chunk |  994109580 |        1 |       215724 |    2504997 |             0 |         0 |         0 |         0 |     214529 |          0 |
       | 2025-02-24 01:48:42.2821+00   |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28906_chunk |  994109719 |        1 |       242093 |    2504997 |             0 |         0 |         0 |         0 |     239972 |          0 |
       | 2025-02-24 01:48:47.196345+00 |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28907_chunk |  994109818 |        1 |       289720 |    2504997 |             0 |         0 |         0 |         0 |     286092 |          0 |
       | 2025-02-24 01:50:32.23867+00  |            0 |                1 |              |
 _timescaledb_internal | _hyper_1_28908_chunk |  994109871 |        1 |    215067536 |    3798354 |      11548824 |    229678 |   1042757 |         0 |     229668 |      56832 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28909_chunk |  994158228 |        2 |    338448078 |    3635850 |      20550157 |    218947 |         0 |         0 |     218947 |          0 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_28910_chunk |  994229082 |        3 |    937361824 |   13236123 |    3795257292 |    675402 |    406402 |         0 |     675402 |     405713 |
       |                               |            0 |                0 |              |
 _timescaledb_internal | _hyper_1_30110_chunk | 1665775592 |        6 |   2188404918 | 1060028053 | 5030717824130 |  63342125 |    408522 |       222 |  515157296 |    4903925 |
       |                               |            0 |                0 |              | 2025-02-14 07:20:23.753905+00
The slow run is performing significantly more disk reads 138484 compared to 100099 for the fast run. This indicates more data is being fetched from disks rather than the shared_buffers. Likely cause is data might not have been cached during the slow run. A quick question do we have this slow run constantly or periodically if I may ask please? 

Some chunks were scanned that returned zero rows so it would be good to fine tune the query to scan just the chunks that need to be scanned.

Some of the chunks seem to be bloated and would benefit from a rebuilt



gcpdsg1-# ORDER BY dead_tuple_percent DESC, s.n_dead_tup DESC;
     chunk_schema      |      chunk_name      | live_tuples | dead_tuples | total_tuples | dead_tuple_percent | total_size_pretty |        last_autovacuum        | autovacuum_count
-----------------------+----------------------+-------------+-------------+--------------+--------------------+-------------------+-------------------------------+------------------
 _timescaledb_internal | _hyper_1_28910_chunk |      675402 |      405713 |      1081115 |              37.53 | 106 GB            |                               |                0
 _timescaledb_internal | _hyper_1_28908_chunk |      229668 |       56832 |       286500 |              19.84 | 62 GB             |                               |                0
 

For the prod executions

Similar to dev the slow run has more disk reads than the fast run indicating during the slow run data blocks are fetched from disks rather than memory.

stats seem to be stale as well and will require us to update stats by running an analyze on the research.daily hypertable.

Indexes on the chunks scanned are being used by the query planner with the right join method nested loop being used due to the amount of rows  fetched 444 which is a small data set. This indicates that the times the query is running slow means the data isn’t in memory and has to be fetched from disk.  Again we would like to find out if slow runs are constant or just periodic

Overall execution paths are the same just different in timing and the right join type is used based on the size of the data set being queried. Also indexes are being used as well. So this can basically be data not being cached for fast access in memory. @Dylan Richards 



Diego Morales 
26 February 2025 at 17:40

Assigning this ticket to the team.



Dylan Richards 
20 February 2025 at 03:05

Open dev_fast_queryplan.json
dev_fast_queryplan.json
20 Feb 2025, 02:56 am
Open dev_slow_queryplan.json
dev_slow_queryplan.json
20 Feb 2025, 02:56 am
Open prod_fast_queryplan.json
prod_fast_queryplan.json
20 Feb 2025, 02:56 am
Open prod_slow_queryplan.json
prod_slow_queryplan.json
20 Feb 2025, 02:56 am
Open test_query.sql

test_query.sql
20 Feb 2025, 02:56 am


In Progress

Actions
SLAs
20 Feb 20:00
Time to resolution
within 4h
26 Feb 17:40
Time to first response
within 4h
Details
Assignee




Rama Selvaraj
Assign to me
Request Type




Service Request
Reporter




Dylan Richards
Time remaining


0m
Organisations



Garda Capital Partners
More fields
Request participants, Labels, Categories, Source, Approvers, Related Asset, External System Case #, Start date, Epic Link, Components, Parent, Due date, Original estimate
Automation

Rule executions
Tempo

Open Tempo
SLA Panel

SLAs
Connector for Salesforce

Associations
Slack Discussion

Open Slack Discussion
Created 20 February 2025 at 03:05
Updated 1 March 2025 at 12:53
Configure

test_query.sql
sql · 112 KB

CREATE temp TABLE pg_temp.dailybulkselecttemp of research.dateserieskeys;
alter table pg_temp.dailybulkselecttemp add primary key ("symbol", "source", "field");
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_57M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_54M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_51M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_48M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_45M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_42M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_39M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_36M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_33M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_30M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_27M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_24M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_21M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_18M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_15M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_12M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_9M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_6M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_FRA_JIBAR3M_3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_57M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_54M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_51M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_48M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_45M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_42M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_39M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_36M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_33M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_30M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_27M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_24M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_21M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_18M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_15M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_12M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_9M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_6M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_FRA_LIBOR3M_3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_57M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_54M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_51M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_48M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_45M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_42M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_39M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_36M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_33M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_30M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_27M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_24M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_21M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_18M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_15M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_12M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_9M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_6M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_FRA_STIBOR3M_3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_57M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_54M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_51M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_48M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_45M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_42M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_39M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_36M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_33M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_30M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_27M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_24M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_21M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_18M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_15M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_12M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_9M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_6M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_FRA_WIBOR3M_3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_57M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_54M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_51M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_48M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_45M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_42M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_39M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_36M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_33M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_30M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_27M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_24M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_21M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_18M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_15M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_12M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_9M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_6M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_FRA_BBR3M_3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_57M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_54M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_51M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_48M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_45M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_42M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_39M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_36M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_33M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_30M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_27M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_24M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_21M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_18M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_15M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_12M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_9M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_6M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_FRA_NIBOR3M_3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_57M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_54M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_51M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_48M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_45M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_42M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_39M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_36M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_33M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_30M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_27M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_24M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_21M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_18M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_15M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_12M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_9M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_6M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_FRA_BUBOR3M_3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_57M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_54M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_51M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_48M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_45M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_42M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_39M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_36M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_33M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_30M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_27M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_24M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_21M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_18M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_15M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_12M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_9M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_6M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_FRA_LIBOR3M_3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_57M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_54M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_51M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_48M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_45M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_42M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_39M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_36M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_33M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_30M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_27M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_24M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_21M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_18M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_15M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_12M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_9M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_6M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_FRA_EURIBOR3M_3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_57M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_54M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_51M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_48M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_45M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_42M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_39M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_36M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_33M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_30M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_27M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_24M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_21M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_18M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_15M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_12M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_9M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_6M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_FRA_CIBOR3M_3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_57M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_54M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_51M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_48M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_45M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_42M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_39M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_36M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_33M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_30M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_27M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_24M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_21M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_18M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_15M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_12M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_9M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_6M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_FRA_PRIBOR3M_3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_57M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_54M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_51M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_48M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_45M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_42M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_39M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_36M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_33M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_30M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_27M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_24M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_21M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_18M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_15M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_12M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_9M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_6M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_FRA_CDOR3M_3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_15Y15Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_10Y10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_4Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_20Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_9M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('ZAR_SWAP_JIBAR3M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_15Y15Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_10Y10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_4Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_20Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_9M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('USD_SWAP_SOFR1D_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_15Y15Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_10Y10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_4Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_20Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_9M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('SEK_SWAP_STIBOR3M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_15Y15Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_10Y10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_4Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_20Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_9M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('PLN_SWAP_WIBOR6M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_15Y15Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_10Y10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_4Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_20Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_9M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NZD_SWAP_BBR3M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_15Y15Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_10Y10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_4Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_20Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_9M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('NOK_SWAP_NIBOR6M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_15Y15Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_10Y10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_4Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_20Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_9M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('HUF_SWAP_BUBOR6M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_15Y15Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_10Y10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_4Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_20Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_9M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('GBP_SWAP_SONIA1D_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_15Y15Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_10Y10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_4Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_20Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_9M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('EUR_SWAP_ESTR1D_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_15Y15Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_10Y10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_4Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_20Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_9M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('DKK_SWAP_CIBOR6M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_15Y15Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_10Y10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_4Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_20Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_9M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CZK_SWAP_PRIBOR6M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_15Y15Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_10Y10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_5Y5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_2Y2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_4Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_3Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_2Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_1Y1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_30Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_10Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_5Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_2Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_20Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_3Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_1Y','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_9M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_3M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
INSERT INTO pg_temp.dailybulkselecttemp("symbol","source", "field") values('CAD_SWAP_CDOR3M_6M3M','Garda_Market','RATE') on conflict("symbol","source","field") do nothing;
-- explain (ANALYZE, COSTS, VERBOSE, BUFFERS, FORMAT JSON) SELECT d.symbol, d."source" , d.field, d."date", d.value FROM research.daily d JOIN pg_temp.dailybulkselecttemp t ON t."symbol" = d."symbol" and t."source" = d."source" and t."field" = d."field" WHERE d."date" BETWEEN '2015-01-25' and '2025-01-25';
-- SELECT d.symbol, d."source" , d.field, d."date", d.value FROM research.daily d JOIN pg_temp.dailybulkselecttemp t ON t."symbol" = d."symbol" and t."source" = d."source" and t."field" = d."field" WHERE d."date" BETWEEN '2015-01-25' and '2025-01-25';

