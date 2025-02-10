create database uber;
use uber;

select * from cleaned_city_data;
select * from cleaned_driver_data;
select * from cleaned_payment_data;
select * from cleaned_rides_data;

--****City-Level Performance Optimization****
--Question: Which are the top 3 cities where Uber should focus more on driver recruitment based on key 
--          metrics such as demand high cancellation rates and driver ratings?
select top 3 c.city_name, count(r.ride_id) as total_rides, avg(r.rating) as avg_driver_rating, sum(case when r.ride_status='Canceled' then 1 else 0 end)
as total_cancelations, (sum(case when r.ride_status = 'Canceled' then 1 else 0 end) * 100.0) / count(r.ride_id) as cancellation_rate
from  cleaned_rides_data r join cleaned_city_data c on r.start_city=c.city_name group by c.city_name order by total_rides desc, avg_driver_rating desc
,cancellation_rate desc;

--****Revenue Leakage Analysis****
--Question: How can you detect rides with fare discrepancies or those marked as "completed" without any
--          corresponding payment?
select r.ride_id, r.ride_status, r.fare as ride_fare, iif(p.fare=r.fare,'No match',r.fare) as payment_fare, iif((r.fare-p.fare) is Null,'No Discrepancy',
'No match') as Discrepancy
from cleaned_rides_data r left join cleaned_payment_data p on r.ride_id=p.ride_id where r.ride_status='Completed';

--****Cancellation Analysis****
--Question:  What are the cancellation patterns across cities and ride categories? How do these patterns
--           correlate with revenue from completed rides?
with citycategory as (select c.city_name, r.dynamic_pricing as ride_categories, r.ride_status, count(ride_id) as total_rides from cleaned_rides_data r join 
cleaned_city_data c on r.start_city=c.city_name group by city_name, dynamic_pricing, ride_status),
citycategorycancellation as (select city_name, sum(case when ride_status='completed' then total_rides else 0 end) as completed_rides, sum(case when
ride_status='canceled' then total_rides else 0 end)*100/sum(total_rides) as cancellation_rates, ride_categories from citycategory group by city_name, ride_categories),
category_revenue as (select city_name, sum(fare) as total_revenue from cleaned_rides_data r join cleaned_city_data c on r.start_city=c.city_name where
ride_status='completed' group by city_name)
select cr.city_name, cr.completed_rides, cr. ride_categories, cr.cancellation_rates, crv.total_revenue from citycategorycancellation cr left join
category_revenue crv on cr.city_name=crv.city_name;

--****Cancellation Patterns by Time of Day****
--Question: Analyze the cancellation patterns based on different times of day. Which hours have the highest cancellation rates, and what is their impact on revenue?
with
bcr as (select sum(fare) as Before_Cancellation_Revenue, datepart(hour,start_time) as Start_hour, count(ride_id) as total_rides,
sum(case when ride_status='canceled' then fare else 0 end) as Canceled_revenue, sum(case when ride_status='canceled' then 1 else 0 end) as Canceled_rides
from cleaned_rides_data group by datepart(hour,start_time)),
hcr as (select canceled_rides*100/total_rides as cancellation_rate, Start_hour from bcr)
select top 1 bcr.Before_Cancellation_Revenue, bcr.Start_hour, hcr.cancellation_rate, (bcr.Before_Cancellation_Revenue - bcr.Canceled_Revenue) as 
impacted_revenue from hcr join bcr on bcr.start_hour=hcr.start_hour order by cancellation_rate desc;

--****Seasonal Fare Variations****
--Question: How do fare amounts vary across different seasons? Identify any significant trends or anomalies in fare distributions.
with ride_seasons as (select ride_id, fare, (case when datepart(month,ride_date) in (12,1,2) then 'Winter' when datepart(month,ride_date) in (3,4,5)
then 'Spring' when datepart(month,ride_date) in (6,7,8) then 'Summer' when datepart(month,ride_date) in (9,10,11) then 'Autumn' else 'Season' end) as Seasons, avg(fare) as average_Fare
from cleaned_rides_data group by ride_date, ride_id, fare) select Seasons, count(ride_id) as Total_Rides, avg(fare) as average_Fare,
sum(fare) as Total_Fare from ride_seasons group by seasons;

--****Average Ride Duration by City****
--Question: What is the average ride duration for each city? How does this relate to customer satisfaction?
with satisfaction as (select start_city, rating, ride_id, abs(datediff(second,start_time,end_time)) as duration_seconds from cleaned_rides_data)
select start_city, count(ride_id) as Total_Rides, avg(duration_seconds)/60 as Duration_in_Minutes, avg(rating) as Average_Rating from satisfaction group by start_city;

--**** Index for Ride Date Performance Improvement****
--Question: How can query performance be improved when filtering rides by date?
create index idx on cleaned_rides_data(ride_date);
select start_city, ride_date, fare from cleaned_rides_data where ride_date between '2021-01-01' and '2024-12-31';

--****View for Average Fare by City****
--Question: How can you quickly access information on average fares for each city?
create view info as
select start_city, avg(fare) as Average_Fares from cleaned_rides_data group by start_city;
select * from info;

--**** View for Driver Performance Metrics****
--Question: What performance metrics can be summarized to assess driver efficiency?
select driver_id, count(ride_id) as Total_rides, sum(distance_km) as Total_Distance, avg(distance_km) as Average_Distance, sum(fare) as Total_Fare, avg(fare) as Average_Distance, 
avg(rating) as Average_Rating, sum(datediff(second, start_time,end_time))/3600 as Total_Distance, 
sum(case when ride_status='canceled' then 1 else 0 end)/count(ride_id) as Cancellation_Rate from cleaned_rides_data where ride_status='completed' group by driver_id
order by Total_Rides desc, Cancellation_Rate asc;

--**** Index on Payment Method for Faster Querying****
-- How can you optimize query performance for payment-related queries?
create index crx2 on cleaned_payment_data(payment_method);
select payment_id, fare, surge_multiplier, payment_method from cleaned_payment_data where payment_method='Cash';