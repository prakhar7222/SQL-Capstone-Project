USE cryptopunk;
SHOW tables;
SELECT * FROM pricedata;

-- 1) How many sales occurred during this time period? 
SELECT COUNT(*) FROM pricedata;

-- 2) Return the top 5 most expensive transactions (by USD price) for this data set. Return the name, ETH price, and USD price, as well as the date.
SELECT * FROM (
  SELECT
    name,
    eth_price,
    usd_price,
    event_date,
    ROW_NUMBER() OVER (ORDER BY usd_price DESC) AS rn
  FROM pricedata
) t WHERE rn <= 5;

-- 3) Return a table with a row for each transaction with an event column, a USD price column, and a moving average of USD price that averages the last 50 transactions.

WITH daily_sales AS (
 	 SELECT
 	   event_date,
 	   usd_price,
 	   AVG(usd_price) OVER (ORDER BY event_date ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) AS moving_avg
	  FROM pricedata
	)
	SELECT
 	 event_date,
	  usd_price,
 	 moving_avg
	FROM daily_sales;
    
-- 4) Return all the NFT names and their average sale price in USD. Sort descending. Name the average column as average_price.
    SELECT
 		 name,
	  AVG(usd_price) AS average_price
	FROM pricedata
	GROUP BY name
	ORDER BY average_price DESC;

-- 5) Return each day of the week and the number of sales that occurred on that day of the week, as well as the average price in ETH. Order by the count of transactions in ascending order.

WITH daily_sales AS (
  	SELECT
    	event_date,
    	seller_address,
    	usd_price,
   	 dayofweek(event_date)  AS day_of_week
 	 FROM pricedata
	)
	SELECT
  	day_of_week,
 	 COUNT(*) AS num_sales,
 	 AVG(usd_price) AS avg_price
	FROM daily_sales
	GROUP BY day_of_week
	ORDER BY num_sales ASC;

-- 6) Construct a column that describes each sale and is called summary. The sentence should include who sold the NFT name, who bought the NFT, who sold the NFT, the date, and what price it was sold for in USD rounded to the nearest thousandth. Here’s an example summary: “CryptoPunk #1139 was sold for $194000 to 0x91338ccfb8c0adb7756034a82008531d7713009d from 0x1593110441ab4c5f2c133f21b0743b2b43e297cb on 2022-01-14”
SELECT
  	name,
 	 eth_price,
  	usd_price,
 	 buyer_address,
  	seller_address,
  	event_date,
  	CONCAT(
   	 'CryptoPunk #',
   	 CAST(SUBSTRING_INDEX(name, '#', -1) AS CHAR),
   	 ' was sold for $',
   	 ROUND(usd_price, 3),
   	 ' to ',
   	 buyer_address,
   	 ' from ',
   	 seller_address,
   	 ' on ',
   	 event_date
 	 ) AS summary
	FROM pricedata;
    
-- 7) Create a view called “1919_purchases” and contains any sales where “0x1919db36ca2fa2e15f9000fd9cdc2edcf863e685” was the buyer

CREATE VIEW 1919_purchases AS
	SELECT * FROM pricedata
	WHERE buyer_address = '0x1919db36ca2fa2e15f9000fd9cdc2edcf863e685';
    
-- 8) Create a histogram of ETH price ranges. Round to the nearest hundred value.

SELECT
 	 FLOOR(eth_price / 100) * 100 AS price_range,
 	 COUNT(*) AS num_sales
	FROM pricedata
	GROUP BY price_range;
    
-- 9) Return a unioned query that contains the highest price each NFT was bought for and a new column called status saying “highest” with a query that has the lowest price each NFT was bought for and the status column saying “lowest”. The table should have a name column, a price column called price, and a status column. Order the result set by the name of the NFT, and the status, in ascending order. 

WITH pricedata AS (
  	SELECT
  	  name,
    	usd_price,
   	 ROW_NUMBER() OVER (PARTITION BY name ORDER BY usd_price DESC) AS rn_high,
  	  ROW_NUMBER() OVER (PARTITION BY name ORDER BY usd_price ASC) AS rn_low
	  FROM pricedata
	)
	SELECT
 	 name,
 	 usd_price AS price,
  	'highest' AS status
	FROM pricedata
	WHERE rn_high = 1
	UNION ALL
	SELECT
  	name,
  	usd_price AS price,
  	'lowest' AS status
	FROM pricedata
	WHERE rn_low = 1;
    
-- 10) What NFT sold the most each month / year combination? Also, what was the name and the price in USD? Order in chronological format. 

WITH monthly_sales AS (
  	SELECT
   	 DATE_FORMAT(event_date, '%Y-%m') AS month_year,
   	 name,
    usd_price
  	FROM pricedata
	)
	SELECT
  	month_year,
 	 name,
 	 usd_price
	FROM monthly_sales
	WHERE (month_year, usd_price) IN (
 	 SELECT
  	  month_year,
  	  MAX(usd_price)
  	FROM monthly_sales
 	 GROUP BY month_year
	);

-- 11) Return the total volume (sum of all sales), round to the nearest hundred on a monthly basis (month/year).

WITH monthly_volume AS (
 	 SELECT
  	  DATE_FORMAT(event_date, '%Y-%m') AS month_year,
  	  SUM(usd_price) AS volume
  	FROM pricedata
  	GROUP BY month_year
	)
	SELECT
  	month_year,
  	ROUND(volume, -2) AS volume
	FROM monthly_volume;

-- 12)  Count how many transactions the wallet "0x1919db36ca2fa2e15f9000fd9cdc2edcf863e685"had over this time period.

SELECT
  	COUNT(*)
	FROM pricedata
	WHERE buyer_address = '0x1919db36ca2fa2e15f9000fd9cdc2edcf863e685';

-- 13) Create an “estimated average value calculator” that has a representative price of the collection every day based off of these criteria:
 -- - Exclude all daily outlier sales where the purchase price is below 10% of the daily average price
 -- - Take the daily average of remaining transactions
-- a) First create a query that will be used as a subquery. Select the event date, the USD price, and the average USD price for each day using a window function. Save it as a temporary table.
 -- b) Use the table you created in Part A to filter out rows where the USD prices is below 10% of the daily average and return a new estimated value which is just the daily average of the filtered data.
 
 WITH daily_sales AS (
 	 SELECT
  	  event_date,
  		  usd_price,
  	  AVG(usd_price) OVER (PARTITION BY event_date) AS daily_avg
 	 FROM pricedata
	),
	filtered_sales AS (
	  SELECT
 	   event_date,
 	   usd_price
 	 FROM daily_sales
	  WHERE usd_price >= 0.1 * daily_avg
	)
	SELECT
 	 event_date,
  	AVG(usd_price) AS estimated_value
	FROM filtered_sales
	GROUP BY event_date;




