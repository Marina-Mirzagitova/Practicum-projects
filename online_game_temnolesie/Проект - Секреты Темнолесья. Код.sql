/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
*/

--Часть 1. Задача 1.1. Подсчёт доли платящих игроков
SELECT COUNT(id) AS total_player,  --общее количество игроков, зарегистрированных в игре
	   SUM(payer) AS total_paid_player,  --количество платящих игроков
	   ROUND(SUM(payer) / COUNT(id) :: NUMERIC, 4) AS part_paid_player  --доля платящих игроков от общего количества пользователей, зарегистрированных в игре
FROM fantasy.users;


--Часть 1. Задача 1.2. Взаимосвязь между долей платящих игроков и расой персонажа
SELECT r.race,  --раса персонажа
	   SUM(u.payer) AS total_paid_player_per_race, --количество платящих игроков
	   COUNT(u.id) AS total_players_per_race,  --общее количество зарегистрированных игроков
	   ROUND(SUM(u.payer) / COUNT(u.id) :: NUMERIC,4) AS part_paid_player_per_race  --доля платящих игроков от общего количества пользователей, зарегистрированных в игре в разрезе каждой расы персонажа
FROM fantasy.users AS u
JOIN fantasy.race AS r ON u.race_id=r.race_id
GROUP BY r.race
ORDER BY part_paid_player_per_race DESC;

--Часть 1. Задача 2.1. Основные статистические показатели по полю покупки amount
SELECT COUNT(amount) AS total_events, --общее количество покупок
	   SUM(amount) AS total_value,  --суммарная стоимость всех покупок
	   MIN(amount) AS min_value, --минимальная  стоимость покупки
	   MAX(amount) AS max_value,  --максимальная стоимость покупки
	   ROUND(AVG(amount)::numeric,2) AS avg_value,  --среднее значение стоимости покупки
	   ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount)::NUMERIC,2) AS mediana_value,  --медиану стоимости покупки
	   ROUND(STDDEV(amount)::NUMERIC,2) AS stdev_value  --стандартное отклонение стоимости покупки
FROM fantasy.events;

--Часть 1. Задача 2.2. Покупки с нулевой стоимостью

SELECT COUNT(amount) AS total_null_pay,  --количество покупок с нулевой стоимостью
	   COUNT(amount) / (SELECT COUNT(transaction_id) --общее количество покупок
	   					FROM fantasy.events) :: NUMERIC AS part_null_pay  --доля покупок с нулевой стоимостью от общего числа покупок
FROM fantasy.events
WHERE amount = 0;


--Часть 1. Задача 2.3. Активность платящих и неплатящих игроков по покупке эпических предметов за «райские лепестки»

WITH total_stats AS (   --СТЕ с общими статистическими показателями для каждой группы (платящие-неплатящие)
	SELECT u.payer,
	   COUNT(DISTINCT u.id) AS count_player,  --общее количество игроков
	   COUNT(e.transaction_id) AS total_events,  --общее количество покупок
	   SUM(e.amount) AS sum_amount  --суммарную стоимость покупок
	FROM fantasy.users AS u
	JOIN fantasy.events AS e ON u.id=e.id
	WHERE amount>0
	GROUP BY u.payer

)

SELECT CASE
			WHEN payer=1 
			THEN 'платящие'
			WHEN payer=0
			THEN 'неплатящие'
	   END AS payer,
	   count_player, 
	   ROUND(total_events/count_player::NUMERIC,2) AS avg_events,  --среднее количество покупок на одного игрока
	   ROUND(sum_amount::NUMERIC/count_player) AS avg_sum_amount_per_player  --средняя суммарная стоимость покупок на одного игрока
FROM total_stats;


--Часть 1. Задача 2.4. Популярность эпических предметов

SELECT i.item_code,
i.game_items,  --эпический предмет
       COUNT(e.transaction_id) AS total_sales,  --общее количество внутриигровых продаж
       ROUND(COUNT(e.transaction_id) / (SELECT COUNT(transaction_id) --подзапрос с общим количеством продаж
       							  FROM fantasy.events) :: NUMERIC,4) AS part_epic_sales,  --доля продажи эпического предмета от всех продаж
       ROUND(COUNT(DISTINCT e.id) / (SELECT COUNT(DISTINCT id) --подзапрос с общим количеством игроков
       						 FROM fantasy.events) :: NUMERIC,4) AS part_epic_item_player  --доля игроков, которые хотя бы раз покупали этот предмет
FROM fantasy.events AS e
JOIN fantasy.items AS i ON i.item_code=e.item_code
WHERE amount>0
GROUP BY i.game_items, i.item_code 
ORDER BY part_epic_item_player DESC;



-- Часть 2. Задача 1. Зависимость активности игроков от расы персонажа

WITH stat_users AS (   --CTE для расчета статистических показателей для каждой расы по пользователям
	SELECT race_id,
	 	   COUNT(DISTINCT id) AS total_users,  --общее количество зарегистрированных игроков
	 	   SUM(payer) AS total_payer --общее количество платящих игроков
	FROM fantasy.users
	GROUP BY race_id
	),
	
	stat_events AS (  --CTE для расчета статистических показателей по покупкам для каждой расы
		SELECT u.race_id,
			   COUNT(DISTINCT e.id) AS total_active_buyers,  --общее количество игроков, которые совершают внутриигровые покупки   
			   COUNT(e.transaction_id) AS total_purchases, --общее количество покупок
			   SUM(e.amount) AS sum_amount --суммарная стоимость всех покупок
		FROM fantasy.users AS u
		JOIN fantasy.events AS e ON u.id=e.id
		WHERE e.amount>0  --убираем аномальные покупки
		GROUP BY u.race_id
	)


SELECT r.race,  --раса
	   total_users,  --общее количество зарегистрированных игроков
	   total_active_buyers,  --общее количество игроков, которые совершают внутриигровые покупки
	   CASE 
	   		WHEN total_users <> 0
	   		THEN ROUND(total_active_buyers / total_users:: NUMERIC, 4) 
	   		ELSE 0
	   END AS share_active_buyers,  --доля количества игроков, которые совершают внутриигровые покупки, от общего количества
	   CASE
	   	   	WHEN total_active_buyers <> 0
	   	   	THEN ROUND(total_payer/total_active_buyers:: NUMERIC, 4) 
	   	   	ELSE 0
	   END AS share_payer_among_buyers,  --доля платящих игроков от количества игроков, которые совершили покупки
	   CASE 
		   WHEN total_users <> 0
		   THEN ROUND(total_purchases / total_users:: NUMERIC, 1) 
		   ELSE 0
	   END AS avg_purchases_per_user, --среднее количество покупок на одного игрока
	   CASE
		   WHEN total_purchases <> 0 
		   THEN ROUND(sum_amount :: NUMERIC / total_purchases) 
		   ELSE 0
	   END AS avg_purchase_value, --средняя стоимость одной покупки на одного игрока
	   CASE 
	   	   WHEN total_users <> 0
	   	   THEN ROUND(sum_amount :: NUMERIC / total_users) 
	   	   ELSE 0
	   END AS avg_sum_amount_per_user --средняя суммарная стоимость всех покупок на одного игрока
FROM stat_users
JOIN stat_events ON stat_users.race_id=stat_events.race_id
JOIN fantasy.race AS r ON stat_users.race_id=r.race_id
ORDER BY avg_sum_amount_per_user DESC;


-- Часть 2. Задача 2. Частота покупок*

WITH purchase_dates AS (  --CTE для расчёта даты предыдущей покупки
	SELECT e.id,
		   e.date,
		   u.payer,
		   LAG(e.date) OVER (PARTITION BY e.id ORDER BY e.date) AS previous_date  --дата предыдущей покупки
	FROM fantasy.events AS e
	JOIN fantasy.users AS u ON e.id = u.id
	WHERE e.amount > 0  -- исключаем покупки с нулевой стоимостью
	),
	
purchase_intervals AS (  --CTE для расчёта количества дней между покупками для каждого игрока
 	SELECT id,
 		   payer,
 		   AGE(date::timestamp, previous_date::timestamp) AS interval_days  --интервал между покупками
  	FROM purchase_dates
  	WHERE previous_date IS NOT NULL
	),

user_purchase_stats AS (  --CTE для расчёта количества покупок и среднего интервала между покупками
  	SELECT id,
  		   payer,
  		   COUNT(*) + 1 AS total_purchases,  -- общее количество покупок, где +1 учитывает первую покупку с previous_date IS NULL
  		   DATE_TRUNC('day', AVG(interval_days)) AS avg_interval_days  --среднее значение по количеству дней между покупками
  	FROM purchase_intervals
  	GROUP BY id, payer
  	HAVING COUNT(*) + 1 >= 25  --только активные клиенты, которые совершили 25 или более покупок
	),
	
ranked_users AS (  --CTE для ранжирования игроков по среднему количеству дней между покупками
 	SELECT *,
           NTILE(3) OVER (ORDER BY avg_interval_days) AS rank_group  --ранжирование игроков по среднему количеству дней между покупками
 	FROM user_purchase_stats
	),

labeled_group AS (  --CTE для присвоения названия группам
  	SELECT *,
    	   CASE rank_group
    	   		WHEN 1 THEN 'высокая частота'
    	   		WHEN 2 THEN 'умеренная частота'
    	   		WHEN 3 THEN 'низкая частота'
    	   END AS name_rank_group
  	FROM ranked_users
	)
	
SELECT name_rank_group,    --Расчёт итоговых показателей по группам
  	   COUNT(*) AS total_users,  --количество игроков, которые совершили покупки
  	   SUM(CASE WHEN payer = 1 THEN 1 ELSE 0 END) AS total_payers,  --количество платящих игроков, совершивших покупки
  	   ROUND(SUM(CASE WHEN payer = 1 THEN 1 ELSE 0 END)::NUMERIC / COUNT(*), 4) AS share_payers,  --доля платящих игроков, совершивших покупки, от общего количества игроков, совершивших покупку
  	   ROUND(AVG(total_purchases), 1) AS avg_purchases_per_user,  --среднее количество покупок на одного игрока
  	   DATE_TRUNC('day', AVG(avg_interval_days)) AS avg_days_between_purchases  --среднее количество дней между покупками на одного игрока
FROM labeled_group
GROUP BY name_rank_group
ORDER BY 
  CASE name_rank_group
    WHEN 'высокая частота' THEN 1
    WHEN 'умеренная частота' THEN 2
    WHEN 'низкая частота' THEN 3
  END;
