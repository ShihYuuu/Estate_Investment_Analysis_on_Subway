-- 1. Which state has the highest average annual number of visits to Subway?

WITH SubwayVisits AS (
 SELECT
   region,
   COUNT(DISTINCT safegraph_place_id) AS subway_count,
   SUM(raw_visit_counts) AS visit_count,
   SUM(raw_visit_counts) / COUNT(DISTINCT safegraph_place_id) AS avg_visits
 FROM
   `tsungyulu-fa24-mgmt58200-final.safegraph.visits`
 WHERE
   location_name = 'Subway'
 GROUP BY
   region
),
SubwayCategories AS (
 SELECT
   top_category,
   sub_category
 FROM
   `tsungyulu-fa24-mgmt58200-final.safegraph.brands`
 WHERE
   brand_name = 'Subway'
),
SubwayRatios AS (
 SELECT
   p.region,
   COUNT(CASE WHEN p.location_name = 'Subway' THEN 1 END) /
   COUNT(CASE WHEN p.location_name != 'Subway' THEN 1 END) AS subway_ratio,
   RANK() OVER (ORDER BY
     COUNT(CASE WHEN p.location_name = 'Subway' THEN 1 END) /
     COUNT(CASE WHEN p.location_name != 'Subway' THEN 1 END) DESC
   ) AS subway_ratio_rank
 FROM
   `tsungyulu-fa24-mgmt58200-final.safegraph.brands` AS b
 JOIN
   `tsungyulu-fa24-mgmt58200-final.safegraph.places` AS p
 ON
   b.brand_name = p.location_name
 WHERE
   p.top_category = (SELECT top_category FROM SubwayCategories)
 AND
   p.sub_category = (SELECT sub_category FROM SubwayCategories)
 GROUP BY
   p.region
)

SELECT
 sv.region,
 sv.subway_count,
 sv.visit_count,
 sv.avg_visits,
 sr.subway_ratio,
 sr.subway_ratio_rank
FROM
 SubwayVisits AS sv
LEFT JOIN
 SubwayRatios AS sr
ON
 sv.region = sr.region
ORDER BY
 sv.avg_visits DESC, subway_ratio_rank DESC;


-- 2. What's the percentage of people in Puerto Rico that have an annual income of less than $15,000, what's the percentage of male and female children in Puerto Rico? And compare the result to the other regions in the U.S.

WITH ranked_data AS (
 SELECT
   cf.state AS state,
   RANK() OVER (ORDER BY (SUM(inc_lt10) + SUM(`inc_10-15`)) / SUM(inc_total) DESC) AS poor_rank,
   RANK() OVER (ORDER BY (SUM(`pop_m_5-9`) + SUM(`pop_m_10-14`))/SUM(pop_total) DESC) AS male_children_rank,
   RANK() OVER (ORDER BY (SUM(`pop_f_5-9`) + SUM(`pop_f_10-14`))/SUM(pop_total) DESC) AS female_children_rank
 FROM
   `tsungyulu-fa24-mgmt58200-final.safegraph.cbg_demographics` AS cd
 JOIN
   `tsungyulu-fa24-mgmt58200-final.safegraph.cbg_fips` AS cf
 ON
   SUBSTR(cd.cbg, 1, 2) = cf.state_fips
 GROUP BY
   cf.state
)

SELECT
 ranked_data.state,
 total_stats.poor_percentage,
 ranked_data.poor_rank,
 total_stats.male_children_percentage,
 ranked_data.male_children_rank,
 total_stats.female_children_percentage,
 ranked_data.female_children_rank,
FROM
 (SELECT
    (SUM(inc_lt10) + SUM(`inc_10-15`))/SUM(inc_total) AS poor_percentage,
    (SUM(`pop_m_5-9`) + SUM(`pop_m_10-14`))/SUM(pop_total) AS male_children_percentage,
    (SUM(`pop_f_10-14`) + SUM(`pop_f_5-9`))/ SUM(pop_total) AS female_children_percentage
 FROM
   `tsungyulu-fa24-mgmt58200-final.safegraph.cbg_demographics` AS cd
 JOIN
   `tsungyulu-fa24-mgmt58200-final.safegraph.cbg_fips` AS cf
 ON
   SUBSTR(cd.cbg, 1, 2) = cf.state_fips
 WHERE
   cf.state = 'PR'
 ) AS total_stats
JOIN
 ranked_data
ON
 ranked_data.state = 'PR';


-- 3. Given the decision to focus on the poor market, which county in Puerto Rico has the highest proportion of poor people?

SELECT
 cf.county,
 (SUM(cd.inc_lt10) + SUM(cd.`inc_10-15`))/SUM(cd.inc_total) AS poor_percentage
FROM
 `tsungyulu-fa24-mgmt58200-final.safegraph.cbg_demographics` AS cd
JOIN
 `tsungyulu-fa24-mgmt58200-final.safegraph.cbg_fips` AS cf
ON
 SUBSTR(cd.cbg, 1, 2) = cf.state_fips
AND
 SUBSTR(cd.cbg, 3, 3) = cf.county_fips
AND
 cf.state = 'PR'
GROUP BY
 cf.county
ORDER BY
 poor_percentage DESC;


-- 4. On which days of the week does the Subway restaurant in Puerto Rico have a higher average number of visits?

WITH DailyVisits AS (
 SELECT
   count(*) as store_count,
   SUM(CAST(JSON_EXTRACT_SCALAR(popularity_by_day, '$.Monday') AS INT64)) AS total_monday,
   SUM(CAST(JSON_EXTRACT_SCALAR(popularity_by_day, '$.Tuesday') AS INT64)) AS total_tuesday,
   SUM(CAST(JSON_EXTRACT_SCALAR(popularity_by_day, '$.Wednesday') AS INT64)) AS total_wednesday,
   SUM(CAST(JSON_EXTRACT_SCALAR(popularity_by_day, '$.Thursday') AS INT64)) AS total_thursday,
   SUM(CAST(JSON_EXTRACT_SCALAR(popularity_by_day, '$.Friday') AS INT64)) AS total_friday,
   SUM(CAST(JSON_EXTRACT_SCALAR(popularity_by_day, '$.Saturday') AS INT64)) AS total_saturday,
   SUM(CAST(JSON_EXTRACT_SCALAR(popularity_by_day, '$.Sunday') AS INT64)) AS total_sunday
 FROM
   `tsungyulu-fa24-mgmt58200-final.safegraph.visits`
 WHERE
   location_name = 'Subway'
 AND
   region = 'PR'
)

SELECT
 total_monday / store_count AS avg_mon_visit,
 total_tuesday / store_count AS avg_tue_visit,
 total_wednesday / store_count AS avg_wed_visit,
 total_thursday / store_count AS avg_thu_visit,
 total_friday / store_count AS avg_fri_visit,
 total_saturday / store_count AS avg_sat_visit,
 total_sunday / store_count AS avg_sun_visit
FROM
 DailyVisits;
