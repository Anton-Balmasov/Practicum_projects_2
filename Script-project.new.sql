/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор:Балмасов Антон
 * Дата:13.11.2025
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id,
    total_area,
    rooms ,
    balcony,
    floor
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
 ),
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
 category as(
 SELECT
 f.id,
 city,
 t.TYPE,
 CASE WHEN  city='Санкт-Петербург' 
 THEN 'Санкт-Петербург'
 ELSE 'ЛенОбл'
 END AS region
FROM real_estate.city c
JOIN real_estate.flats f ON  c.city_id =f.city_id 
JOIN real_estate."type" t ON f.type_id =t.type_id 
WHERE t.type ='город'
),
day_activity  AS (
SELECT
f.id, 
a.last_price,
a.first_day_exposition,
CASE 
WHEN days_exposition BETWEEN 1 AND 30 THEN 'до месяца'
WHEN days_exposition BETWEEN 31 AND 90 THEN 'до трех месяцев'
WHEN days_exposition BETWEEN 91 AND 180 THEN 'до полугода'
WHEN days_exposition >180 THEN 'более полугода'
ELSE 'active'
END AS segment
FROM real_estate.advertisement a 
JOIN  real_estate.flats f ON a.id=f.id
WHERE a.first_day_exposition BETWEEN '01-01-2015' AND '31-12-2018'
)
---
SELECT
c.region AS "регион",
d.segment AS "сегмент",
count(*)AS "кол-во обьявлений",
round(avg(d.last_price/f.total_area)::numeric,2)AS "средняя стомость кв.метра",
round(avg(f.total_area)::numeric,2) AS "средняя площадь",
PERCENTILE_CONT(0.5) WITHIN group(ORDER BY f.rooms)AS "медиана кол-во комнат",
PERCENTILE_CONT(0.5) WITHIN group(ORDER BY f.balcony ) AS "медиана кол-во балконов",
PERCENTILE_CONT(0.5) WITHIN group(ORDER BY f.floor ) AS "медиана этажности"
FROM  category AS c 
JOIN day_activity AS d ON c.id=d.id
JOIN filtered_id AS f ON d.id=f.id
GROUP BY c.region ,d.segment 
ORDER BY "кол-во обьявлений" DESC ;


 
 


-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
SELECT a.id,
a.first_day_exposition,
a.days_exposition ,
a.last_price,
f.total_area,
f.rooms,
CASE WHEN a.days_exposition IS NOT NULL THEN
a.first_day_exposition + INTERVAL '1 day'* days_exposition
END AS removal_date
FROM real_estate.advertisement a 
jOIN real_estate.flats f ON a.id=f.id
JOIN real_estate."type" t ON f.type_id =t.type_id 
WHERE a.first_day_exposition BETWEEN '01-01-2015' AND '31-12-2018' AND t."type" = 'город' 
and
        f.total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
publication_stats as(
 SELECT
 EXTRACT (MONTH FROM first_day_exposition)AS month_num,
 count(*) AS publication_count,
 round(avg(last_price/total_area)::NUMERIC,2) AS avg_price_publication,
 round(avg(total_area)::numeric,2) AS avg_area_publication
 FROM filtered_id 
GROUP BY month_num
),
removal_stat as(
SELECT 
 EXTRACT (MONTH FROM removal_date)AS month_num,
 count(*) AS removal_count,
 round(avg(last_price/total_area)::NUMERIC,2) AS avg_price_removal,
 round(avg(total_area)::numeric,2) AS avg_area_removal
 FROM filtered_id f
 WHERE f.days_exposition IS NOT null
GROUP BY month_num 
)
SELECT p.month_num AS "месяц публикации",
p.publication_count AS "кол-во публикаций",
r.removal_count AS "кол-во снятий",
p.avg_price_publication AS "ср цена кв м при публикации",
r.avg_price_removal AS "ср.цена кв м при снятии",
p.avg_area_publication AS "ср площадь при публикации",
r.avg_area_removal AS "средняя площадь при снятии" 
FROM publication_stats AS p
join removal_stat r ON p.month_num=r.month_num 
ORDER BY "месяц публикации";  