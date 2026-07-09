use sm;
CREATE TABLE posts (
    Post_ID VARCHAR(20) PRIMARY KEY,
    Timestamp DATETIME,
    Platform VARCHAR(30),
    Content_Type VARCHAR(30),
    Category VARCHAR(30),
    Likes INT,
    Comments INT,
    Shares INT,
    Views INT,
    Saves INT,
    Follower_Count INT,
    Engagement_Rate DECIMAL(6,2),
    Hour_of_Day INT,
    Day_of_Week VARCHAR(15),
    Hashtag_Count INT,
    Content_Length INT,
    Sentiment VARCHAR(15),
    Influencer_Tier VARCHAR(20),
    Has_Media BOOLEAN,
    Is_Verified BOOLEAN
);

-- Data loaded via LOAD DATA LOCAL INFILE from the Python-cleaned CSV
 
-- Engineered columns added after load
ALTER TABLE posts
    ADD COLUMN Total_Interactions INT,
    ADD COLUMN Hashtag_Bucket VARCHAR(20);
 
UPDATE posts
SET Total_Interactions = Likes + Comments + Shares + Saves;
 
UPDATE posts
SET Hashtag_Bucket = CASE
    WHEN Hashtag_Count <= 5 THEN 'Low'
    WHEN Hashtag_Count <= 10 THEN 'Medium'
    ELSE 'High'
END;
 
 
/* ------------------------------------------------------------
   1. AGGREGATIONS: Basic engagement patterns by dimension
   ------------------------------------------------------------ */
 
-- 1.1 Average engagement rate by category, highest to lowest
SELECT AVG(Engagement_Rate) AS Avg_Eng_Rate, Category
FROM posts
GROUP BY Category
ORDER BY Avg_Eng_Rate DESC;
 
-- 1.2 Average engagement rate by platform
SELECT AVG(Engagement_Rate) AS Avg_Eng_Rate, Platform
FROM posts
GROUP BY Platform;
 
-- 1.3 Post count and average total interactions by influencer tier
SELECT COUNT(Post_ID) AS count_post_id,
       AVG(Total_Interactions) AS avg_Total_Interactions,
       Influencer_Tier
FROM posts
GROUP BY Influencer_Tier;
 
 
/* ------------------------------------------------------------
   2. COMPARISONS: Verified accounts, hashtags, sentiment
   ------------------------------------------------------------ */
 
-- 2.1 Verified vs non-verified accounts
SELECT Is_Verified, AVG(Engagement_Rate) AS avg_eng_rate
FROM posts
GROUP BY Is_Verified;
 
-- 2.2 Engagement by hashtag volume bucket (sweet spot check)
SELECT Hashtag_Bucket, AVG(Engagement_Rate) AS avg_eng_rate
FROM posts
GROUP BY Hashtag_Bucket;
 
-- 2.3 Engagement by sentiment
SELECT Sentiment, AVG(Engagement_Rate) AS avg_eng_rate
FROM posts
GROUP BY Sentiment;
 
 
/* ------------------------------------------------------------
   3. WINDOW FUNCTIONS: Rankings and comparisons within groups
   ------------------------------------------------------------ */
 
-- 3.1 Rank every post's engagement rate within its own category
SELECT Post_ID, Category, Engagement_Rate,
       RANK() OVER (PARTITION BY Category ORDER BY Engagement_Rate DESC) AS category_rank
FROM posts;
 
-- 3.2 Top 3 highest-engagement posts per platform
-- (window functions can't be filtered directly in WHERE, so wrap in a CTE)
WITH ranked_posts AS (
    SELECT Post_ID, Platform, Engagement_Rate,
           RANK() OVER (PARTITION BY Platform ORDER BY Engagement_Rate DESC) AS Platform_rank
    FROM posts
)
SELECT *
FROM ranked_posts
WHERE Platform_rank <= 3;
 
-- 3.3 Each post's engagement rate vs. its category average
SELECT Post_ID, Category, Engagement_Rate,
       AVG(Engagement_Rate) OVER (PARTITION BY Category) AS avg_category,
       Engagement_Rate - AVG(Engagement_Rate) OVER (PARTITION BY Category) AS diff_from_avg
FROM posts;
 
 
/* ------------------------------------------------------------
   4. CTEs: Multi-step logic (best hours, content length buckets)
   ------------------------------------------------------------ */
 
-- 4.1 Top 3 best-performing posting hours
WITH hrs AS (
    SELECT Hour_of_Day, AVG(Engagement_Rate) AS avg_engagement
    FROM posts
    GROUP BY Hour_of_Day
)
SELECT *
FROM hrs
ORDER BY avg_engagement DESC
LIMIT 3;
 
-- 4.2 Engagement by content length bucket (short / medium / long)
WITH cte3 AS (
    SELECT Post_ID, Engagement_Rate,
        CASE
            WHEN Content_Length < 100 THEN 'Short'
            WHEN Content_Length <= 500 THEN 'Medium'
            ELSE 'Long'
        END AS Buck_content_Length
    FROM posts
)
SELECT Buck_content_Length, AVG(Engagement_Rate) AS avg_eng_rate
FROM cte3
GROUP BY Buck_content_Length;
 
 
/* ------------------------------------------------------------
   5. CROSS-DIMENSIONAL: Day of week x Platform
   ------------------------------------------------------------ */
 
-- 5.1 Average engagement by day of week and platform
-- Key finding: TikTok leads every single day of the week,
-- with Friday showing its strongest performance (~86.6 avg engagement)
SELECT Day_of_Week, Platform, AVG(Engagement_Rate) AS avg_eng_rate
FROM posts
GROUP BY Day_of_Week, Platform
ORDER BY Day_of_Week, avg_eng_rate DESC;