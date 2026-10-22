-- ============================================================
-- Правки к домашнему заданию к лекции «SQL. Введение»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Коняхин Никита Андреевич


SET search_path TO hh_school;


-- ============================================================
-- БЛОК Г. Соединение таблиц
-- ============================================================


-- ЗАДАНИЕ Г2
-- Запрос 1: все работодатели, число вакансий и откликов (LEFT JOIN)
SELECT
    e.employer_name,
    count(DISTINCT v.vacancy_id) AS vacancies_cnt,
    count(r.response_id) AS responses_cnt
FROM employers e
LEFT JOIN vacancies v ON e.employer_id = v.employer_id
LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY e.employer_id, e.employer_name
ORDER BY responses_cnt DESC, e.employer_name;

-- Запрос 2: тот же запрос с INNER JOIN
SELECT
    e.employer_name,
    count(DISTINCT v.vacancy_id) AS vacancies_cnt,
    count(r.response_id) AS responses_cnt
FROM employers e
INNER JOIN vacancies v ON e.employer_id = v.employer_id
INNER JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY e.employer_id, e.employer_name
ORDER BY responses_cnt DESC, e.employer_name;


-- доп. поиск 
-- инфа по вакансии
SELECT
    v.vacancy_id,
    v.vacancy_name,
    v.professional_role,
    v.area_id,
    v.published_at,
    v.closed_at,
    (v.closed_at IS NULL) AS is_open,        
    v.salary_from,
    (v.salary_from IS null) AS salary_missing  
FROM vacancies v
JOIN employers e ON v.employer_id = e.employer_id
WHERE e.employer_name = 'ГринЭнерго'
ORDER BY v.published_at;

--инфа по похожим
SELECT
    e.employer_name,
    count(DISTINCT v.vacancy_id) AS vacancies_cnt,
    count(r.response_id) AS responses_cnt,
    count(r.response_id) FILTER (WHERE r.status = 'invited') AS invited_cnt
FROM vacancies v
JOIN employers e ON v.employer_id = e.employer_id
LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
WHERE v.professional_role IN (
        SELECT v2.professional_role
        FROM vacancies v2
        JOIN employers e2 ON v2.employer_id = e2.employer_id
        WHERE e2.employer_name = 'ГринЭнерго'
      )
GROUP BY e.employer_name
ORDER BY responses_cnt DESC;


-- Вывод:
-- 1. Количество вакансий приходится считать через count(DISTINCT), а не через count(*), 
--    потому что после соединения с таблицей responses одна вакансия дублируется столько раз, сколько у неё откликов. 
--    Обычный count(*) посчитал бы строки результата, а нужно чистое число уникальных объектов.

-- 2. Во втором запросе исчезла «ГринЭнерго», ноль откликов пока это гипотеза:
--    был проверен контекст её вакансии (id 1043, «Стажёр: разработчик», Казань) —
--    она опубликована 06.04.2026 и уже закрыта 04.05.2026, а зарплата не указана, поэтому тишина объяснима состоянием объявления.
--    Фон по направлению «Разработчик» бодрый (УралСофт 53, Северный Код 45, Стартап Ноль 24, ТехноБанк 17 откликов), ноль есть у «СибирьТелеком», значит проблема адресная. 
--    Итоговая рекомендация HR: предложить перезалить вакансию с зарплатной вилкой; вопрос про интерес уместен только по открытым позициям.

-- 3. Правило! 
--    если нужны только связанные данные, то берём INNER JOIN. 
--    если нужно сохранить всю основу отчёта, даже  при отсутствии связей, то берем LEFT JOIN.


-- ============================================================
-- БЛОК Д. Функции и финальный кейс
-- ============================================================

-- ЗАДАНИЕ Д1
-- Запрос: помесячная динамика откликов и конверсия
-- (месяц как дата, условный агрегат, nullif в знаменателе)
SELECT
    date_trunc('month', created_at)::date AS month,
    count(response_id) AS responses_cnt,
    count(response_id) FILTER (WHERE status = 'invited') AS invited_cnt,
    round(100.0 * count(response_id) FILTER (WHERE status = 'invited') / nullif(count(response_id), 0),1) AS conversion_pct
FROM responses
GROUP BY 1
ORDER BY 1;

-- проверка полноты последнего месяца
SELECT max(created_at) AS last_response_at
FROM responses;
-- август оборван на середине 2026-08-15

-- Вывод:
-- Максимальная конверсия была в июне 2026 года = 19,5%. 
-- Этому месяцу можно доверять, так как объём выборки репрезентативен, было получено 118 откликов.
-- Последний месяц неполный, здесь всего 41 отклик и конверсия резко упала до 7,3%, август оборван на середине 2026-08-15.
-- При планировании набора ориентируемся на полные, август не учитываем.


-- ============================================================
-- БЛОК Е. Со звёздочкой
-- ============================================================

-- ЗАДАНИЕ Е1
-- Исходный запрос (выполнить и посмотреть результат):
SELECT v.professional_role,
       count(*) AS vacancies,
       sum(v.salary_from) AS total_salary,
       count(r.response_id) / count(*) AS responses_per_vacancy
FROM vacancies v
JOIN responses r ON v.vacancy_id = r.vacancy_id
WHERE v.closed_at = NULL
GROUP BY 1;

-- Результат: пустота.


-- Ошибки (минимум четыре):
-- 1. WHERE v.closed_at = NULL 
--    Сравнение с NULL через = всегда ложно, нужно использовать IS NULL. (из-за этого запрос возвращает пустой набор данных)
-- 2. JOIN с responses
--    Это убирает все вакансии, у которых нет ни одного отклика.
--    Для анализа нужно использовать LEFT JOIN, чтобы сохранить все вакансии.
-- 3. count(*) AS vacancies
--    После присоединения таблицы откликов одна вакансия повторяется в строках столько раз, сколько у неё откликов. 
--    count(*) посчитает общее число строк соединения, а не число уникальных вакансий. 
--    Тут надо использовать count(DISTINCT v.vacancy_id).
-- 4. count(r.response_id) / count(*)
--    Выражение выполняет целочисленное деление, теряя дробную часть.
--    Надо приводить к float (умножать на 1.0) и защищать знаменатель через nullif().



-- Исправленный запрос:
SELECT 
    v.professional_role,
    COUNT(DISTINCT v.vacancy_id) AS vacancies_cnt,
    (SELECT COALESCE(AVG(salary_from), 0)  -- применен AVG
     FROM vacancies 
     WHERE professional_role = v.professional_role AND closed_at IS NULL) AS avg_salary,  
    COUNT(r.response_id) AS responses_cnt,
    ROUND(1.0 * COUNT(r.response_id) / NULLIF(COUNT(DISTINCT v.vacancy_id), 0), 2) AS avg_responses_per_vacancy
FROM vacancies v
LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
WHERE v.closed_at IS NULL
GROUP BY v.professional_role;


-- написан CTE!!:
WITH vacancy_stats AS (
    -- метрики по вакансиям
    SELECT 
        professional_role,
        COUNT(*) AS vacancies_cnt,
        AVG(salary_from) AS avg_salary
    FROM vacancies
    WHERE closed_at IS NULL
    GROUP BY professional_role
),
response_stats AS (
    -- метрики по откликам
    SELECT 
        v.professional_role,
        COUNT(r.response_id) AS responses_cnt,
        COUNT(r.response_id) FILTER (WHERE r.status = 'invited') AS invited_cnt
    FROM vacancies v
    LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
    WHERE v.closed_at IS NULL
    GROUP BY v.professional_role
)
--соединяем
SELECT 
    vs.professional_role,
    vs.vacancies_cnt,
    vs.avg_salary,
    rs.responses_cnt,
    rs.invited_cnt,
    ROUND(1.0 * rs.responses_cnt / NULLIF(vs.vacancies_cnt, 0), 2) AS avg_responses_per_vacancy,
    ROUND(100.0 * rs.invited_cnt / NULLIF(rs.responses_cnt, 0), 1) AS conversion_pct
FROM vacancy_stats vs
LEFT JOIN response_stats rs USING (professional_role)
ORDER BY vs.professional_role;

-- Какие два правила из лекции защитили бы от этих ошибок при написании запроса:
-- 1. Правило NULL: пустоту проверяют только через IS NULL / IS NOT NULL. 
--    Сравнение с NULL даёт UNKNOWN и отсекает все строки.
-- 2. Правило JOIN один ко многим: после соединения дочерней таблицы строки родителя дублируются. 
--    Нельзя считать count(*) или sum() по полям родителя, для этого нужен LEFT JOIN (чтобы не терять объекты без связей), 
--    count(DISTINCT primary_key) для подсчёта уникальных объектов и nullif() в знаменателе любого отношения.
