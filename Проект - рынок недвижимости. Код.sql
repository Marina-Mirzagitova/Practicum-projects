-- Проект первого модуля: анализ данных для агентства недвижимости
-- Часть 2. Решаем ad hoc задачи
 
-- Автор: Мирзагитова Марина
-- Дата: 18.06.2025

--Задача 1. Время активности объявлений
--Расчет аномальных значений (выбросы) по значению перцентилей

WITH limits AS (
	SELECT PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,  --аномально высокие значения общей площади квартиры
		   PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,  --аномально высокие значения количества комнат
		   PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,  --аномально высокие значения количества балконов
		   PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_99,  --аномально высокие значения высоты потолка
		   PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_1  --аномально низкие значения высоты потолка
	FROM real_estate.flats 
	),

--Фильтрация аномальных значений (поиск id объявлений, которые не содержат выбросы)	
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE total_area < (SELECT total_area_limit FROM limits)  --ограничение по общей площади квартиры
    	  AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)  --ограничение по количеству  комнат
          AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)  --ограничение по количеству балконов
          AND ((ceiling_height < (SELECT ceiling_height_limit_99 FROM limits)
          	AND ceiling_height > (SELECT ceiling_height_limit_1 FROM limits)) OR ceiling_height IS NULL)  --ограничение по высоте потолка
    ),	

 --Сегментация рынка недвижимости по принадлежности к городу и длительности публикации объявления
category AS ( 
	SELECT *,
		   CASE 
	   			WHEN city_id = '6X8I'
				THEN 'Санкт-Петербург'
				ELSE 'города Ленинградской области'
	  	   END AS city_group,  --сегментация рынка недвижимости по принадлежности к городу
	  	   CASE
	  	   		WHEN days_exposition <= 30
	  	   		THEN 1
	  	   		WHEN days_exposition > 30 AND days_exposition <=90
	  	   		THEN 2
	  	   		WHEN days_exposition > 90 AND days_exposition <=180
	  	   		THEN 3
	  	   		ELSE 4
	  	   END AS days_category  --сегментация рынка недвижимости по длительности публикации объявления
	FROM real_estate.flats
	JOIN real_estate.advertisement USING(id)
	WHERE type_id = 'F8EM' AND id IN (SELECT * FROM filtered_id) --ограничение на принадлежность к населенному пункту типа город и отфильтрованные значения от выбросов
		  AND days_exposition IS NOT NULL  --фильтруем "активные" объявления
	),
	

	--Расчет общих показателей для Санкт-Петербурга и городов Ленинградской области
	total_indicators AS (
	SELECT city_group,
		   COUNT(*) AS total_count_ads_per_city,  --общее количество объявлений для каждого сегмента
		   SUM(COALESCE(is_apartment, 0)) AS total_count_is_apartment,  --общее количество апартаментов для каждого сегмента
		   SUM(COALESCE(open_plan, 0)) AS total_count_open_plan  --общее количество квартир с открытой планировкой для каждого сегмента
	FROM category
	GROUP BY city_group 
)

--Основной запрос
SELECT CASE
			WHEN days_category=1
			THEN 'до месяца'
			WHEN days_category=2
			THEN 'до трех месяцев'
			WHEN days_category=3
			THEN 'до полугода'
			ELSE 'больше полугода'
	   END AS period,  --присвоение имен для сегментов рынка недвижимости по длительности публикации объявления
	   city_group,
	   ROUND(AVG(days_exposition)::numeric,2) AS avg_days_exposition,  --среднее количество дней активности объявления
	   COUNT(*) AS count_ads,  --общее количество рекламных объявлений для каждого сегмента
	   ROUND(COUNT(*) :: NUMERIC / total_count_ads_per_city, 4) AS share_ads,  --доля рекламных объявлений в разрезе каждого региона
	   ROUND(AVG(last_price/total_area)::numeric,2) AS avg_cost_per_sq_m,  --средняя стоимость квадратного метра
	   ROUND(AVG(total_area)::numeric,2) AS avg_total_area,  --средняя площадь недвижимости
	   ROUND(AVG(kitchen_area)::numeric,2) AS avg_kitchen_area,  --средняя площадь кухни
	   ROUND(AVG(floors_total)::numeric,2) AS avg_floors_total,  --средняя этажность дома, в котором находится квартира
	   ROUND(AVG(rooms)::numeric,2) AS avg_count_rooms,  --среднее число комнат
	   ROUND(AVG(balcony)::numeric,2) AS avg_count_balcony,  --среднее количество балконов
	   ROUND(AVG(ceiling_height)::numeric,2) AS avg_ceiling_height,  --средняя высота потолков
	   ROUND(SUM(COALESCE(is_apartment, 0)) :: NUMERIC / total_count_is_apartment, 4) AS share_is_apartment,  --доля апартаментов от общего числа по городу 
	   ROUND(SUM(COALESCE(open_plan, 0)) :: NUMERIC / total_count_open_plan, 4) AS share_open_plan  --доля квартир с открытой планировкой от общего числа по городу 
FROM category
JOIN real_estate.city USING(city_id)
JOIN total_indicators USING(city_group)
GROUP BY days_category, city_group, total_count_ads_per_city, total_count_is_apartment, total_count_open_plan
ORDER BY city_group, days_category;



--Задача 2. Сезонность объявлений
--Расчет аномальных значений (выбросы) по значению перцентилей

WITH limits AS (
	SELECT PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,  --аномально высокие значения общей площади квартиры
		   PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,  --аномально высокие значения количества комнат
		   PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,  --аномально высокие значения количества балконов
		   PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_99,  --аномально высокие значения высоты потолка
		   PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_1  --аномально низкие значения высоты потолка
	FROM real_estate.flats 
	),

--Фильтрация аномальных значений (поиск id объявлений, которые не содержат выбросы)	
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE total_area < (SELECT total_area_limit FROM limits)  --ограничение по общей площади квартиры
    	  AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)  --ограничение по количеству  комнат
          AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)  --ограничение по количеству балконов
          AND ((ceiling_height < (SELECT ceiling_height_limit_99 FROM limits)
          	AND ceiling_height > (SELECT ceiling_height_limit_1 FROM limits)) OR ceiling_height IS NULL)  --ограничение по высоте потолка
    ),	
  
--Расчет месяцев публикации объявлений и снятия с продажи недвижимости
months_ads AS (
	SELECT *,
		   EXTRACT(MONTH FROM first_day_exposition) AS month_first_ads, --месяц объявления
		   EXTRACT(MONTH FROM (first_day_exposition + days_exposition * INTERVAL '1 days')) AS month_last_ads  --месяц снятия объявления
	FROM real_estate.flats
	JOIN real_estate.advertisement USING(id) 
    WHERE type_id = 'F8EM' AND id IN (SELECT * FROM filtered_id) --ограничение на принадлежность к населенному пункту типа город и отфильтрованные значения от выбросов
),
    
--Расчет активности публикации объявлений
first_exposition AS (
	SELECT month_first_ads AS month_ads, --месяц объявления
		   COUNT(*) AS count_first_ads,	--количество опубликованных объявлений
		   ROUND(AVG(last_price/total_area)::numeric,2) AS first_avg_cost_per_sq_m,  --средняя стоимость квадратного метра при размещении объявления
	   	   ROUND(AVG(total_area)::numeric,2) AS first_avg_total_area,  --средняя площадь недвижимости при размещении объявления
	   	   ROUND(COUNT(*) :: NUMERIC / (SELECT COUNT(*)
	   									FROM months_ads), 4
	   									) AS share_ads  --доля рекламных объявлений
	FROM months_ads
	WHERE EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018  --убрали из анализа данные за неполные 2014 и 2019 года
	GROUP BY month_first_ads
),    
    
--Расчет активности в публикациях по снятию объявления
last_exposition AS (
	SELECT month_last_ads AS month_ads,  --месяц снятия объявления
		   COUNT(*) AS count_last_ads, --количество объявлений, снятых с продажи
		   ROUND(AVG(last_price/total_area)::numeric,2) AS last_avg_cost_per_sq_m,  --средняя стоимость квадратного метра при продаже недвижимости
	       ROUND(AVG(total_area)::numeric,2) AS last_avg_total_area,  --средняя площадь недвижимости при продаже недвижимости
	       ROUND(COUNT(days_exposition)::NUMERIC / (SELECT COUNT(*)
	   							  					FROM months_ads), 4) AS share_off_market --доля снятых с публикации объявлений
	FROM months_ads
	WHERE days_exposition IS NOT NULL --фильтрация объявлений, которые еще не сняты с продажы
	GROUP BY month_last_ads
)

--Основной запрос
SELECT CASE 
			WHEN month_ads=1 THEN 'январь'
			WHEN month_ads=2 THEN 'февраль'
			WHEN month_ads=3 THEN 'март'
			WHEN month_ads=4 THEN 'апрель'
			WHEN month_ads=5 THEN 'май'
			WHEN month_ads=6 THEN 'июнь'
			WHEN month_ads=7 THEN 'июль'
			WHEN month_ads=8 THEN 'август'
			WHEN month_ads=9 THEN 'сентябрь'
			WHEN month_ads=10 THEN 'октябрь'
			WHEN month_ads=11 THEN 'ноябрь'
			WHEN month_ads=12 THEN 'декабрь'
	   END AS month_ads_name,
	   RANK() OVER (ORDER BY COALESCE(count_first_ads,0) DESC) AS rank_publication,
	   count_first_ads,
	   first_avg_cost_per_sq_m,
	   first_avg_total_area,
	   share_ads,
	   RANK() OVER (ORDER BY COALESCE(count_last_ads,0) DESC) AS rank_removal,
	   count_last_ads,
	   last_avg_cost_per_sq_m,
	   last_avg_total_area,
	   share_off_market
FROM first_exposition
FULL JOIN last_exposition USING (month_ads)
ORDER BY first_avg_cost_per_sq_m DESC;


--Задача 3. Анализ рынка недвижимости Ленобласти
--Расчет аномальных значений (выбросы) по значению перцентилей

WITH limits AS (
	SELECT PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,  --аномально высокие значения общей площади квартиры
		   PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,  --аномально высокие значения количества комнат
		   PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,  --аномально высокие значения количества балконов
		   PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_99,  --аномально высокие значения высоты потолка
		   PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_1  --аномально низкие значения высоты потолка
	FROM real_estate.flats 
	),

--Фильтрация аномальных значений (поиск id объявлений, которые не содержат выбросы)	
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE total_area < (SELECT total_area_limit FROM limits)  --ограничение по общей площади квартиры
    	  AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)  --ограничение по количеству  комнат
          AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)  --ограничение по количеству балконов
          AND ((ceiling_height < (SELECT ceiling_height_limit_99 FROM limits)
          	AND ceiling_height > (SELECT ceiling_height_limit_1 FROM limits)) OR ceiling_height IS NULL)  --ограничение по высоте потолка
    ),
    
--Сегментация рынка недвижимости по принадлежности к городу
category AS ( 
	SELECT *
	FROM real_estate.flats
	JOIN real_estate.advertisement USING(id)
	WHERE city_id <> '6X8I' AND id IN (SELECT * FROM filtered_id) AND days_exposition IS NOT NULL --ограничение на принадлежность к Ленинградской области (исключаем Санкт-Петербург) и отфильтрованные значения от выбросов
),

--Расчет итоговых показателей в разрезе городов Лен.области
city_stats AS (
	SELECT city,
	   COUNT(*) AS count_ads,  --общее количество рекламных объявлений для каждого города Ленинской области
	   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY days_exposition) AS median_days_exposition,  --медианное количество дней активности объявления
	   ROUND(COUNT(*) :: NUMERIC / (SELECT COUNT(*)
	   								FROM category), 4
	   								) AS share_ads,  --доля рекламных объявлений в разрезе каждого города
	   ROUND(COUNT(days_exposition)::NUMERIC / (SELECT COUNT(*)
	   							  				FROM category), 4) AS share_off_market, --доля снятых с публикации объявлений в городах Ленинградской области
	   ROUND(AVG(last_price/total_area)::numeric,2) AS avg_cost_per_sq_m,  --средняя стоимость квадратного метра
	   ROUND(AVG(total_area)::numeric,2) AS avg_total_area,  --средняя площадь недвижимости
	   ROUND(AVG(kitchen_area)::numeric,2) AS avg_kitchen_area,  --средняя площадь кухни
	   ROUND(AVG(floors_total)::numeric,2) AS avg_floors_total,  --средняя этажность дома, в котором находится квартира
	   ROUND(AVG(rooms)::numeric,2) AS avg_count_rooms,  --среднее число комнат
	   ROUND(AVG(balcony)::numeric,2) AS avg_count_balcony,  --среднее количество балконов
	   ROUND(AVG(ceiling_height)::numeric,2) AS avg_ceiling_height  --средняя высота потолков
	FROM category
	JOIN real_estate.city USING(city_id)
	GROUP BY city
)
	
--Основной запрос
SELECT *
FROM city_stats
ORDER BY share_off_market DESC
LIMIT 20; --топ 20 населенных пунктов с хорошими показателями продаж (share_off_market)

