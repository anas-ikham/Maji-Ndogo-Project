-- ----------FULL PROJECT MAJI NDOGO - RESOLVING WATER SOURCE PROBLEMS---------------

USE md_water_services;

-- --------PART I : Beginning Our Data-Driven Journey in Maji Ndogo--------
--  1. Get to know our data:
 SHOW TABLES;
 Select * from water_source limit 10;
 Select * from visits limit 10;
 Select * from location;
 
 --  2. Dive into the water sources:
 Select distinct type_of_water_source from water_source;
 /* An important note on the home taps: About 6-10 million people have running water installed in their homes in Maji Ndogo, including
 broken taps. If we were to document this, we would have a row of data for each home, so that one record is one tap. That means our
 database would contain about 1 million rows of data, which may slow our systems down. For now, the surveyors combined the data of
 many households together into a single record*/
 
 --  3. Unpack the visits to water sources:
 -- SQL query that retrieves all records from this table where the time_in_queue is more than some crazy time, say 500 min. How would it feel to queue 8 hours for water?
 Select * from visits
 where time_in_queue > 500; 
 --  4. Assess the quality of water sources:
 SELECT ws.*, wq.subjective_quality_score
 from visits v
 inner join water_quality wq
 on v.record_id = wq.record_id
 inner join water_source ws
 on ws.source_id = v.source_id
 where subjective_quality_score = 10
 and type_of_water_source like 'tap%';
 --  5. Investigate pollution issues:
SELECT * FROM md_water_services.well_pollution
where biological > 0.01
and results='Clean' 
and description like 'Clean%' ;

 SELECT * FROM well_pollution
 WHERE
 description LIKE "Clean_%"
 OR (results = "Clean" AND biological > 0.01);

-- Case 1a: Update descriptions that mistakenly mention `Clean Bacteria: E. coli` to `Bacteria: E. coli`
UPDATE well_pollution
SET description = 'Bacteria: E. coli'
WHERE description = 'Clean Bacteria: E. coli';
-- Case 1b: Update descriptions that mistakenly mention `Clean Bacteria: Giardia Lamblia` to `Bacteria: Giardia Lamblia`
UPDATE well_pollution
SET description = 'Bacteria: Giardia Lamblia'
WHERE description = 'Clean Bacteria: Giardia Lamblia';
-- Case 2: Update the `result` to `Contaminated: Biological` where `biological` is greater than 0.01 and the current results are `Clean`
UPDATE md_water_services.well_pollution
SET results = 'Contaminated: Biological'
WHERE biological > 0.01
  AND results = 'Clean';

 CREATE TABLE well_pollution_copy
 AS ( SELECT * FROM md_water_services.well_pollution );

SELECT source_id
FROM water_source
GROUP BY source_id
ORDER BY num DESC;

SELECT distinct name, round(SUM(pop_n) * 1000, 2) AS total_population
FROM global_water_access
WHERE name = 'Maji Ndogo'
GROUP BY name;


/*Create a query to identify potentially suspicious field workers based on an anonymous tip. 
This is the description we are given:
The employee’s phone number contained the digits 86 or 11. 
The employee’s last name started with either an A or an M. 
The employee was a Field Surveyor.*/
Select * from employee
where position='Field Surveyor'
AND (phone_number like '%86%' or phone_number like '%11%')
And (employee_name like '%_A%' or employee_name like '%_M%');

SELECT *
FROM well_pollution
WHERE description LIKE 'Clean_%' OR results = 'Clean' AND biological < 0.01;

SELECT * FROM water_quality 
WHERE visit_count >= 2 
AND subjective_quality_score = 10;

SELECT * FROM well_pollution
WHERE description IN ('Parasite: Cryptosporidium', 'biologically contaminated')
OR (results = 'Clean' AND biological > 0.01);

 
-- --------PART II : Clustering data to unveil Maji Ndogo's water crisis--------

--  Cleaning our data
/*We can determine the email address for each employee by:
- selecting the employee_name column
- replacing the space with a full stop
- make it lowercase
- and stitch it all together */

SELECT REPLACE(employee_name, ' ','.')  /*Replace the space with a full stop*/
FROM employee;
SELECT
LOWER(REPLACE(employee_name, ' ','.'))
FROM employee;
 SELECT
 CONCAT(
 LOWER(REPLACE(employee_name, ' ', '.')), '@ndogowater.gov') AS new_email
 FROM md_water_services.employee;
 
UPDATE md_water_services.employee
SET email = CONCAT(LOWER(REPLACE(employee_name, ' ', '.')), '@ndogowater.gov');

SELECT LENGTH(phone_number) FROM employee;
Select phone_number, trim(phone_number) from employee;
update employee
set phone_number=trim(phone_number);

--  Honouring the workers

Select town_name, count(*) AS employee_count
from employee
group by town_name;

SELECT assigned_employee_id, COUNT(*) AS number_of_visits
FROM visits
GROUP BY assigned_employee_id
ORDER BY assigned_employee_id
LIMIT 3;

SELECT assigned_employee_id, COUNT(*) AS number_of_visits
FROM visits
GROUP BY assigned_employee_id
ORDER BY number_of_visits ASC;

-- Analysing locations:
SELECT * FROM location;

Select  count(*) as records_per_town, town_name
from location
group by town_name
order by records_per_town desc;
Select  count(*) as records_per_province, province_name
from location
group by province_name
order by records_per_province desc;

Select  province_name, town_name, count(*) as records_per_town
from location
group by  province_name, town_name
order by province_name, records_per_town desc;
Select  count(*) as num_sources, location_type
from location
group by location_type
order by num_sources;

-- Diving into the sources:
SELECT 23740 / (15910 + 23740) * 100; -- ~60%

SELECT * FROM water_source;
Select  sum(number_of_people_served) as people_served from water_source;
SELECT type_of_water_source, COUNT(*) AS count_of_sources
FROM water_source
GROUP BY type_of_water_source
order by count_of_sources desc;
SELECT type_of_water_source, AVG(number_of_people_served) AS average_people_served
FROM water_source
GROUP BY type_of_water_source;

-- the average number of people that are served by each water source:
Select  type_of_water_source, sum(number_of_people_served) as people_served, 
		round((sum(number_of_people_served) / 27000000)*100, 0) as percentage_people_per_source
from water_source
GROUP BY type_of_water_source
order by percentage_people_per_source desc;

--  Start of a solution:

SELECT type_of_water_source, total_population_served,
       RANK() OVER (ORDER BY total_population_served DESC) AS rank_by_population
FROM (
    SELECT type_of_water_source, SUM(number_of_people_served) AS total_population_served
    FROM water_source
    GROUP BY type_of_water_source
) AS aggregated_data;

SELECT source_id, type_of_water_source, number_of_people_served,
       ROW_NUMBER() OVER (PARTITION BY type_of_water_source ORDER BY number_of_people_served DESC) AS priority_rank
FROM water_source
ORDER BY type_of_water_source, priority_rank;

-- Analysing queues

SELECT * FROM visits;
-- 1. How long did the survey take?
SELECT 
    MIN(time_of_record) AS start_date,
    MAX(time_of_record) AS end_date,
    DATEDIFF(MAX(time_of_record), MIN(time_of_record)) AS survey_duration_in_days
FROM visits;
-- 2. What is the average total queue time for water?
SELECT AVG(NULLIF(time_in_queue, 0)) AS average_queue_time
FROM visits;
-- 3. What is the average queue time on different days?
SELECT 
    DAYNAME(time_of_record) AS day_of_week,
    round(AVG(NULLIF(time_in_queue, 0)), 0) AS average_queue_time
FROM visits
GROUP BY day_of_week
ORDER BY 
    FIELD(day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');
-- 4. How can we communicate this information efficiently?
SELECT 
    TIME_FORMAT(TIME(time_of_record), '%H:00') AS hour_of_day,
    round(AVG(NULLIF(time_in_queue, 0)), 0) AS average_queue_time
FROM visits
GROUP BY hour_of_day
ORDER BY hour_of_day;
/*By adding AVG() around the CASE() function, we calculate the average, but since all of the other days' values are 0, we get an average for Sunday
 only, rounded to 0 decimals. To aggregate by the hour, we can group the data by hour_of_day, and to make the table chronological, we also order
 by hour_of_day.*/
SELECT
 TIME_FORMAT(TIME(time_of_record), '%H:00') AS hour_of_day,-- Sunday
 ROUND(AVG(
 CASE
 WHEN DAYNAME(time_of_record) = 'Sunday' THEN time_in_queue
 ELSE NULL
 END
 ),0) AS Sunday,-- Monday
 ROUND(AVG(
 CASE
 WHEN DAYNAME(time_of_record) = 'Monday' THEN time_in_queue
 ELSE NULL
 END
 ),0) AS Monday,-- Tuesday
 ROUND(AVG(
 CASE
 WHEN DAYNAME(time_of_record) = 'Tuesday' THEN time_in_queue
 ELSE NULL
 END
 ),0) AS Tuesday,
 ROUND(AVG(
 CASE
 WHEN DAYNAME(time_of_record) = 'Wednesday' THEN time_in_queue
 ELSE NULL
 END
 ),0) AS Wednesday,
 -- Wednesday
 ROUND(AVG(
 CASE
 WHEN DAYNAME(time_of_record) = 'Thursday' THEN time_in_queue
 ELSE NULL
 END
 ),0) AS Thursday,
 ROUND(AVG(
 CASE
 WHEN DAYNAME(time_of_record) = 'Friday' THEN time_in_queue
 ELSE NULL
 END
 ),0) AS Friday,
 ROUND(AVG(
 CASE
 WHEN DAYNAME(time_of_record) = 'Saturday' THEN time_in_queue
 ELSE NULL
 END
 ),0) AS Saturday
 FROM visits
 WHERE time_in_queue != 0 -- this excludes other sources with 0 queue times
 GROUP BY hour_of_day
 ORDER BY hour_of_day;

-- We can take it as a pivot table to visualize queue times for different days and hours
/*
 Insights

 1. Most water sources are rural.
 2. 43% of our people are using shared taps. 2000 people often share one tap.
 3. 31% of our population has water infrastructure in their homes, but within that group, 
	45% face non-functional systems due to issues with pipes, pumps, and reservoirs.
 4. 18% of our people are using wells of which, but within that, only 28% are clean..
 5. Our citizens often face long wait times for water, averaging more than 120 minutes.
 6. In terms of queues:
	- Queues are very long on Saturdays.
    - Queues are longer in the mornings and evenings.
    - Wednesdays and Sundays have the shortest queues
*/
/*
Start of our plan
 We have started thinking about a plan:
 1. We want to focus our efforts on improving the water sources that affect the most people.
	- Most people will benefit if we improve the shared taps first.
    - Wells are a good source of water, but many are contaminated. Fixing this will benefit a lot of people.
    - Fixing existing infrastructure will help many people. If they have running water again, they won't have to queue, thereby shorting queue times for
	  others. So we can solve two problems at once.
	- Installing taps in homes will stretch our resources too thin, so for now, if the queue times are low, we won't improve that source.
 2. Most water sources are in rural areas. We need to ensure our teams know this as this means they will have to make these repairs/upgrades in
    rural areas where road conditions, supplies, and labour are harder challenges to overcome.
*/

/*
 Practical solutions
 1. If communities are using rivers, we can dispatch trucks to those regions to provide water temporarily in the short term, while we send out
 crews to drill for wells, providing a more permanent solution.
 2. If communities are using wells, we can install filters to purify the water. For wells with biological contamination, we can install UV filters that
 kill microorganisms, and for *polluted wells*, we can install reverse osmosis filters. In the long term, we need to figure out why these sources
 are polluted.
 3. For shared taps, in the short term, we can send additional water tankers to the busiest taps, on the busiest days. We can use the queue time
 pivot table we made to send tankers at the busiest times. Meanwhile, we can start the work on installing extra taps where they are needed.
 According to UN standards, the maximum acceptable wait time for water is 30 minutes. With this in mind, our aim is to install taps to get
 queue times below 30 min.
 4. Shared taps with short queue times (< 30 min) represent a logistical challenge to further reduce waiting times. The most effective solution,
 installing taps in homes, is resource-intensive and better suited as a long-term goal.
 5. Addressing broken infrastructure offers a significant impact even with just a single intervention. It is expensive to fix, but so many people
 can benefit from repairing one facility. For example, fixing a reservoir or pipe that multiple taps are connected to. We will have to find the
 commonly affected areas though to see where the problem actually is.
*/

-- --------PART III :  Weaving the data threads of Maji Ndogo's narrative--------


SELECT CONCAT(day(time_of_record), " ", monthname(time_of_record), " ", year(time_of_record)) FROM visits;
SELECT
    name,
    wat_bas_r - LAG(wat_bas_r) OVER (PARTITION BY name ORDER BY year) AS arc
FROM 
    global_water_access
ORDER BY
    name;

SELECT 
    location_id,
    time_in_queue,
    AVG(time_in_queue) OVER (PARTITION BY location_id ORDER BY visit_count) AS total_avg_queue_time
FROM 
    visits
WHERE 
visit_count > 1 -- Only shared taps were visited > 1
ORDER BY 
    location_id, time_of_record;
    
--  Integrating the Auditor's report

Select ar.location_id, ar.type_of_water_source as auditor_source,
		ws.type_of_water_source as survey_source, vs.record_id, 
		ar.true_water_source_score as auditor_score, 
        wq.subjective_quality_score as surveyor_score
from auditor_report as ar
Join visits as vs
join water_quality as wq
join water_source as ws
on ar.location_id = vs.location_id
and vs.record_id=wq.record_id
and ar.type_of_water_source=ws.type_of_water_source
WHERE wq.subjective_quality_score != ar.true_water_source_score
and vs.visit_count= 1 ;

-- We use Incorrect_records to find all of the records where the auditor and employee scores don't match.
CREATE VIEW Incorrect_records AS 	
Select ar.location_id,
		vs.record_id,
		em.employee_name,
        ar.true_water_source_score as auditor_score, 
        wq.subjective_quality_score as surveyor_score,
        ar.statements AS statements
From auditor_report as ar
Join visits as vs
on ar.location_id = vs.location_id
join water_quality as wq
on vs.record_id = wq.record_id
join employee as em
on vs.assigned_employee_id = em.assigned_employee_id
WHERE wq.subjective_quality_score != ar.true_water_source_score
and vs.visit_count = 1 ;

Select * from incorrect_records;


-- We then used error_count to aggregate the data, and got the number of mistakes each employee made.
WITH error_count as -- This CTE calculates the number of mistakes each employee made
(SELECT  employee_name, 
		count(employee_name) as number_of_mistakes
FROM Incorrect_records
group by employee_name),
avg_error_count_per_empl AS (
 SELECT AVG(number_of_mistakes) AS avg_mistakes
 FROM error_count
),
--  3. Finally, suspect_list retrieves the data of employees who make an above-average number of mistakes.
suspect_list AS(
SELECT ec.employee_name, ec.number_of_mistakes
FROM error_count ec
JOIN avg_error_count_per_empl as avg
ON ec.number_of_mistakes > avg.avg_mistakes)

select * from suspect_list;
 -- Gathering evidence:

SELECT employee_name, location_id, statements
FROM Incorrect_records ir
WHERE ir.employee_name IN (SELECT employee_name FROM suspect_list)
and statements like "%cash%";

SELECT
    auditorRep.location_id,
    visitsTbl.record_id,
    Empl_Table.employee_name,
    auditorRep.true_water_source_score AS auditor_score,
    wq.subjective_quality_score AS employee_score
FROM auditor_report AS auditorRep
JOIN visits AS visitsTbl
ON auditorRep.location_id = visitsTbl.location_id
JOIN water_quality AS wq
ON visitsTbl.record_id = wq.record_id
JOIN employee as Empl_Table
ON Empl_Table.assigned_employee_id = visitsTbl.assigned_employee_id;

/*Conclusion:
 So we can sum up the evidence we have for Zuriel Matembo, Malachi Mavuso, Bello Azibo and Lalitha Kaburi:
 1. They all made more mistakes than their peers on average.
 2. They all have incriminating statements made against them, and only them.
	Keep in mind, that this is not decisive proof, but it is concerning enough that we should flag it.
*/



-- --------PART IV :  Charting the course for Maji Ndogo's water future--------

 -- Joining pieces together
 /*
  Let's summarise the data we need, and where to find it:
 All of the information about the location of a water source is in the location table, 
	specifically the town and province of that water source.
 water_source has the type of source and the number of people served by each source.
 visits has queue information, and connects source_id to location_id. There were multiple visits to sites, so we need to be careful to
 include duplicate data (visit_count > 1 ).
 well_pollution has information about the quality of water from only wells, so we need to keep that in mind when we join this table.
 */
 
 /* Things that spring to mind :
 1. Are there any specific provinces, or towns where some sources are more abundant?
 2. We identified that tap_in_home_broken taps are easy wins. Are there any towns where this is a particular problem?
 */
 CREATE VIEW combined_analysis_table AS
 -- This view assembles data from different tables into one to simplify analysis
 SELECT
 water_source.type_of_water_source,
 location.town_name,
 location.province_name,
 location.location_type,
 water_source.number_of_people_served,
 visits.time_in_queue,
 well_pollution.results
 FROM
 visits
 LEFT JOIN well_pollution
 ON well_pollution.source_id = visits.source_id
 INNER JOIN location
 ON location.location_id = visits.location_id
 INNER JOIN water_source
 ON water_source.source_id = visits.source_id
 WHERE visits.visit_count = 1;
--  The last analysis
/* We're building another pivot table! 
	This time, we want to break down our data into provinces or towns and source types. 
    If we understand where the problems are, and what we need to improve at those locations, 
    we can make an informed decision on where to send our repair teams.*/
    
WITH province_totals AS (-- This CTE calculates the population of each province
 SELECT province_name, SUM(people_served) AS total_ppl_serv
 FROM combined_analysis_table
 GROUP BY province_name
 )
 SELECT
 ct.province_name,-- These case statements create columns for each type of source.-- The results are aggregated and percentages are calculated
 ROUND((SUM(CASE WHEN source_type = 'river'
 THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS river,
 ROUND((SUM(CASE WHEN source_type = 'shared_tap'
 THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS shared_tap,
 ROUND((SUM(CASE WHEN source_type = 'tap_in_home'
 THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home,
 ROUND((SUM(CASE WHEN source_type = 'tap_in_home_broken'
 THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home_broken,
 ROUND((SUM(CASE WHEN source_type = 'well'
 THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS well
 FROM combined_analysis_table ct
 JOIN province_totals pt ON ct.province_name = pt.province_name
 GROUP BY ct.province_name
 ORDER BY ct.province_name;


 SELECT
 location.address,
 location.town_name,
 location.province_name,
 water_source.source_id,
 water_source.type_of_water_source,
 well_pollution.results
 FROM water_source
 LEFT JOIN well_pollution ON water_source.source_id = well_pollution.source_id
 INNER JOIN visits ON water_source.source_id = visits.source_id
 INNER JOIN location ON location.location_id = visits.location_id;
SELECT
 province_name,
 town_name,
 ROUND(tap_in_home_broken / (tap_in_home_broken + tap_in_home) * 100,0) AS Pct_broken_taps
 FROM town_aggregated_water_access;

--  Summary report:
/*
 Insights:
 Ok, so let's sum up the data we have.
 A couple of weeks ago we found some interesting insights:
 1. Most water sources are rural in Maji Ndogo.
 2. 43% of our people are using shared taps. 2000 people often share one tap.
 3. 31% of our population has water infrastructure in their homes, but within that group,
 4. 45% face non-functional systems due to issues with pipes, pumps, and reservoirs. Towns like Amina, the rural parts of Amanzi, 
	and a couple of towns across Akatsi and Hawassa have broken infrastructure.
 5. 18% of our people are using wells of which, but within that, only 28% are clean. These are mostly in Hawassa, Kilimani and Akatsi.
 6. Our citizens often face long wait times for water, averaging more than 120 minutes:
	• Queues are very long on Saturdays.
	• Queues are longer in the mornings and evenings.
	• Wednesdays and Sundays have the shortest queues.
*/

/*
Practical solutions:
 1. If communities are using rivers, we will dispatch trucks to those regions to provide water temporarily in the short term, while we send out
 crews to drill for wells, providing a more permanent solution. Sokoto is the first province we will target.
 2. If communities are using wells, we will install filters to purify the water. For chemically polluted wells, we can install reverse osmosis (RO)
 filters, and for wells with biological contamination, we can install UV filters that kill microorganisms- but we should install RO filters too. In
 the long term, we must figure out why these sources are polluted.
 3. For shared taps, in the short term, we can send additional water tankers to the busiest taps, on the busiest days. We can use the queue time
 pivot table we made to send tankers at the busiest times. Meanwhile, we can start the work on installing extra taps where they are needed.
 According to UN standards, the maximum acceptable wait time for water is 30 minutes. With this in mind, our aim is to install taps to get
 queue times below 30 min. Towns like Bello, Abidjan and Zuri have a lot of people using shared taps, so we will send out teams to those
 towns first.
 4. Shared taps with short queue times (< 30 min) represent a logistical challenge to further reduce waiting times. The most effective solution,
 installing taps in homes, is resource-intensive and better suited as a long-term goal.
 5. Addressing broken infrastructure offers a significant impact even with just a single intervention. It is expensive to fix, but so many people can
 benefit from repairing one facility. For example, fixing a reservoir or pipe that multiple taps are connected to. We identified towns like Amina,
 Lusaka, Zuri, Djenne and rural parts of Amanzi seem to be good places to start.
*/

 CREATE TABLE Project_progress (
 Project_id SERIAL PRIMARY KEY,
 /* Project_id −− Unique key for sources in case we visit the same
 source more than once in the future.
 */
 source_id VARCHAR(20) NOT NULL REFERENCES water_source(source_id) ON DELETE CASCADE ON UPDATE CASCADE,
 /* source_id −− Each of the sources we want to improve should exist,
	and should refer to the source table. This ensures data integrity.
 */
 Address VARCHAR(50), -- Street address
 Town VARCHAR(30),
 Province VARCHAR(30),
 Source_type VARCHAR(50),
 Improvement VARCHAR(50), -- What the engineers should do at that place
 Source_status VARCHAR(50) DEFAULT 'Backlog' CHECK (Source_status IN ('Backlog', 'In progress', 'Complete')),
 /* Source_status −− We want to limit the type of information engineers can give us, so we
 limit Source_status.
 − By DEFAULT all projects are in the "Backlog" which is like a TODO list.
 − CHECK() ensures only those three options will be accepted. This helps to maintain clean data.
 */
 Date_of_completion DATE, -- Engineers will add this the day the source has been upgraded.
 Comments TEXT -- Engineers can leave comments. We use a TEXT type that has no limit on char length
 );


/*
 At a high level, the Improvements are as follows:
 1. Rivers → Drill wells
 2. wells: if the well is contaminated with chemicals → Install RO filter
 3. wells: if the well is contaminated with biological contaminants → Install UV and RO filter
 4. shared_taps: if the queue is longer than 30 min (30 min and above) → Install X taps nearby where X number of taps is calculated using X
	= FLOOR(time_in_queue / 30).
 5. tap_in_home_broken → Diagnose local infrastructure
*/
-- Project_progress_query
 SELECT
 location.address,
 location.town_name,
 location.province_name,
 water_source.source_id,
 water_source.type_of_water_source,
 well_pollution.results,
 CASE
    -- Rivers → Drill wells
    WHEN water_source.type_of_water_source = 'river' THEN 'Drill well'
    
    -- Wells: Contaminated with chemicals → Install RO filter
    WHEN water_source.type_of_water_source = 'well' AND well_pollution.results = 'Contaminated: Chemical' THEN 'Install RO filter'
    
    -- Wells: Contaminated with biological contaminants → Install UV and RO filter
    WHEN water_source.type_of_water_source = 'well' AND well_pollution.results = 'Contaminated: Biological' THEN 'Install UV and RO filter'
    
    -- Shared taps: Queue time is 30 min or more → Install X taps nearby
    WHEN water_source.type_of_water_source = 'shared_tap' AND visits.time_in_queue >= 30 THEN CONCAT('Install ', FLOOR(visits.time_in_queue / 30), ' taps nearby')
    
    -- Tap in home broken → Diagnose local infrastructure
    WHEN water_source.type_of_water_source = 'tap_in_home_broken' THEN 'Diagnose local infrastructure'
    
    -- Default: No improvement needed
    ELSE NULL
  END AS Improvements
 FROM water_source
 LEFT JOIN well_pollution ON water_source.source_id = well_pollution.source_id
 INNER JOIN visits ON water_source.source_id = visits.source_id
 INNER JOIN location ON location.location_id = visits.location_id;
 
 
 