-- ============================================================
-- Доработка домашнего задания к лекции «Продвинутый SQL»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Коняхин Никита Андреевич


SET search_path TO hh_school;


-- Блок Г. Сложные типы данных
-- 6. Сложные типы данных
-- 6.1. Теги звонков

WITH calls_7d AS (
    SELECT
        c.call_id,
        c.status,
        c.call_tags
    FROM hh_school.calls AS c
    JOIN hh_school.responses AS r
      ON r.response_id = c.response_id
    WHERE c.caller_role = 'employer'
      AND c.call_at >= r.created_at
      AND c.call_at <  r.created_at + INTERVAL '7 day'
)

SELECT
    COUNT(*) AS contradictory_calls,
    STRING_AGG(call_id::text, ', ' ORDER BY call_id) AS contradictory_call_ids
FROM calls_7d
WHERE NOT (
        (status = 'successful'
             AND 'connected' = ANY(call_tags)
             AND NOT 'no_answer' = ANY(call_tags)
             AND NOT 'technical_error' = ANY(call_tags))
     OR
        (status = 'unsuccessful'
             AND 'no_answer' = ANY(call_tags)
             AND NOT 'connected' = ANY(call_tags)
             AND NOT 'technical_error' = ANY(call_tags))
     OR
        (status = 'error'
             AND 'technical_error' = ANY(call_tags)
             AND NOT 'connected' = ANY(call_tags)
             AND NOT 'no_answer' = ANY(call_tags))
);


-- шаг 2

WITH calls_7d AS (
    SELECT
        c.call_id,
        c.status,
        c.call_tags
    FROM hh_school.calls AS c
    JOIN hh_school.responses AS r
      ON r.response_id = c.response_id
    WHERE c.caller_role = 'employer'
      AND c.call_at >= r.created_at
      AND c.call_at <  r.created_at + INTERVAL '7 day'
),

calls_valid AS (
    SELECT call_id, status, call_tags
    FROM calls_7d
    WHERE (status = 'successful'
               AND 'connected' = ANY(call_tags)
               AND NOT 'no_answer' = ANY(call_tags)
               AND NOT 'technical_error' = ANY(call_tags))
       OR (status = 'unsuccessful'
               AND 'no_answer' = ANY(call_tags)
               AND NOT 'connected' = ANY(call_tags)
               AND NOT 'technical_error' = ANY(call_tags))
       OR (status = 'error'
               AND 'technical_error' = ANY(call_tags)
               AND NOT 'connected' = ANY(call_tags)
               AND NOT 'no_answer' = ANY(call_tags))
)

SELECT
    COUNT(*) AS valid_calls,
    COUNT(*) FILTER (WHERE 'screening' = ANY(call_tags)) AS screening_calls,
    COUNT(*) FILTER (WHERE 'interview' = ANY(call_tags)) AS interview_calls,
    COUNT(*) FILTER (WHERE 'follow_up' = ANY(call_tags)) AS follow_up_calls,
    COUNT(*) FILTER (WHERE 'details'   = ANY(call_tags)) AS details_calls,
    COUNT(*) FILTER (
        WHERE 'screening'  = ANY(call_tags)
           OR 'interview'  = ANY(call_tags)
           OR 'follow_up'  = ANY(call_tags)
           OR 'details'    = ANY(call_tags)
    ) AS calls_with_business_tag,
    ROUND(AVG(CARDINALITY(call_tags))::numeric, 2) AS avg_tags_per_valid_call
FROM calls_valid;

-- valid_calls = 108.
-- screening = 25
-- interview = 31
-- follow_up = 29
-- details   = 23
-- Проверка: 25 + 31 + 29 + 23 = 108 = valid_calls, у каждого звонка ровно один бизнес-тег.
-- calls_with_business_tag = 108, все валидные звонки содержат хотя бы один бизнес-тег.
-- avg_tags_per_valid_call = 4,  структура тегов звонка строгая






-- 6.2. Метаданные сообщений

WITH messages_7d AS (
    SELECT
        m.message_id,
        m.message_meta
    FROM hh_school.messages AS m
    JOIN hh_school.responses AS r
      ON r.response_id = m.response_id
    WHERE m.sender_role = 'employer'
      AND m.sent_at >= r.created_at
      AND m.sent_at <  r.created_at + INTERVAL '7 day'
),

message_attrs AS (
    SELECT
        message_id,
        COALESCE(message_meta ->> 'channel', '(без канала)') AS channel,
        message_meta ? 'is_read' AS has_is_read,
        (message_meta ->> 'is_read')::boolean AS is_read,
        COALESCE(jsonb_array_length(message_meta -> 'attachments'), 0) AS attachments_count
    FROM messages_7d
)

SELECT
    channel,
    COUNT(*) AS messages_count,
    COUNT(*) FILTER (WHERE has_is_read) AS with_is_read_flag,
    COUNT(*) FILTER (WHERE has_is_read AND NOT is_read) AS unread_count,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE has_is_read AND NOT is_read)
        / NULLIF(COUNT(*) FILTER (WHERE has_is_read), 0),
        2
    ) AS unread_share_pct,
    COUNT(*) FILTER (WHERE attachments_count > 0) AS with_attachment_count,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE attachments_count > 0) / COUNT(*),
        2
    ) AS attachment_share_pct
FROM message_attrs
GROUP BY channel
ORDER BY channel;


-- ДОРАБОТКА (вывод полностью переписан для лучшей структуризации)

-- Вывод по 6.2:

-- web:
--   messages_count = 628
--   with_is_read_flag = 628  (признак прочтения присутствует у всех сообщений)
--   unread_count = 52
--   unread_share_pct = 8.28 (среди сообщений где признак прочтения известен)
--   with_attachment_count = 25
--   attachment_share_pct = 3.98

-- mobile_app:
--   messages_count = 360
--   with_is_read_flag = 360  (признак прочтения присутствует у всех сообщений)
--   unread_count = 36
--   unread_share_pct = 10.00 (среди сообщений где признак прочтения известен)
--   with_attachment_count = 14
--   attachment_share_pct = 3.89

-- Проверка: 628 + 360 = 988 — сходится с числом сообщений работодателя.

-- Наблюдения: web это основной канал переписки работодателя (628 из 988).
-- Доля непрочитанных сообщений на mobile_app немного выше(10.00% и 8.28%), а доля сообщений с вложениями на обоих каналах близка (3.89% и 3.98%).














-- Блок Д. Самостоятельное исследование
-- 7. Что связано с приглашением?

-- H1:
--    по откликам, завершившимся приглашением, работодатель коммуницирует интенсивнее:
--    медианное число коммуникаций в первые 7 дней выше, и чаще используются оба канала сразу (сообщения + звонки), чем по остальным откликам.
--    аспект 1: интенсивность; аспект 2: канальный микс.

-- H2:
--    по откликам с приглашением работодатель выходит на связь быстрее:
--    медиана времени до первой коммуникации ниже, а доля откликов, где первый контакт произошёл в первые 24 часа, выше, чем по остальным откликам.
--    аспект 3: скорость.


WITH response_scope AS (
    SELECT
        r.response_id,
        r.created_at AS response_created_at,
        r.status AS response_status,
        v.employer_id,
        v.professional_role
    FROM hh_school.responses AS r
    JOIN hh_school.vacancies AS v
      ON v.vacancy_id = r.vacancy_id
),

events AS (
    SELECT
        rs.response_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM hh_school.messages AS m
    JOIN response_scope AS rs
      ON rs.response_id = m.response_id
    WHERE m.sender_role = 'employer'
      AND m.sent_at >= rs.response_created_at
      AND m.sent_at <  rs.response_created_at + INTERVAL '7 day'

    UNION ALL

    SELECT
        rs.response_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM hh_school.calls AS c
    JOIN response_scope AS rs
      ON rs.response_id = c.response_id
    WHERE c.caller_role = 'employer'
      AND c.call_at >= rs.response_created_at
      AND c.call_at <  rs.response_created_at + INTERVAL '7 day'
),

response_features AS (
    SELECT
        rs.response_id,
        rs.response_status,
        COUNT(e.event_at) AS communication_count,
        COUNT(e.event_at) FILTER (WHERE e.event_type = 'message') AS message_count,
        COUNT(e.event_at) FILTER (WHERE e.event_type = 'call') AS call_count,
        MIN(e.event_at) AS first_communication_at,
        EXTRACT(EPOCH FROM (MIN(e.event_at) - rs.response_created_at)) / 3600.0
                                                                   AS hours_to_first,
        MIN(e.event_at) < rs.response_created_at + INTERVAL '1 day'
                                                                   AS first_within_24h,
        (COUNT(e.event_at) FILTER (WHERE e.event_type = 'message') > 0
             AND COUNT(e.event_at) FILTER (WHERE e.event_type = 'call') > 0)
                                                                   AS is_multichannel,
        (ARRAY_AGG(e.event_type ORDER BY e.event_at, e.event_type, e.event_id)
            FILTER (WHERE e.event_type IS NOT NULL))[1] = 'call' AS first_is_call
    FROM response_scope AS rs
    LEFT JOIN events AS e          
      ON e.response_id = rs.response_id
    GROUP BY
        rs.response_id,
        rs.response_status,
        rs.response_created_at
)

SELECT
    CASE WHEN rf.response_status = 'invited'
         THEN 'invited' ELSE 'other' END                          AS response_group,

    COUNT(*) AS responses_total,
    COUNT(*) FILTER (WHERE rf.communication_count > 0) AS responses_with_communication,

    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rf.communication_count)::numeric, 2)
                                                                  AS median_communications,
    ROUND(AVG(rf.communication_count)::numeric, 2) AS avg_communications,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE rf.is_multichannel)
        / NULLIF(COUNT(*) FILTER (WHERE rf.communication_count > 0), 0),
        2
    )                                                             AS multichannel_share_pct,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE rf.first_is_call)
        / NULLIF(COUNT(*) FILTER (WHERE rf.communication_count > 0), 0),
        2
    )                                                             AS first_contact_call_share_pct,

    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rf.hours_to_first)
        FILTER (WHERE rf.hours_to_first IS NOT NULL)::numeric, 2) AS median_hours_to_first,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE rf.first_within_24h)
        / NULLIF(COUNT(*) FILTER (WHERE rf.communication_count > 0), 0),
        2
    )                                                             AS first_within_24h_share_pct
FROM response_features AS rf
GROUP BY 1
ORDER BY 1;



-- ДОРАБОТКА

-- Вывод по H1:
-- invited (N = 92, с коммуникацией 54): медиана коммуникаций = 2, среднее = 1.63, мультиканальность = 14.81%
-- other (N = 536, с коммуникацией 328): медиана = 3, среднее = 1.76, мультиканальность = 17.38%

-- Все метрики интенсивности у invited ниже, чем у other:
-- медианное число коммуникаций 2 против 3, среднее 1.63 против 1.76, доля мультиканальных откликов 14.81% против 17.38%.
-- и все же масштаб различий небольшой: средние отличаются на 0.13 события, мультиканальность на 2.57 п.п. 
-- разрыв медиан на единицу не будем считать как кратную разницу, т к медиана целочисленного показателя дискретна и может сдвинуться на единицу при малом сдвиге распределения
-- поэтому честный масштаб различия тут показывает среднее.
-- Направление всех метрик противоречит гипотезе, поэтому H1 не подтверждается.
-- итог: гипотеза не подтвердилась ((




-- ДОРАБОТКА

-- Вывод по H2:
-- Группы с коммуникацией: invited 54, other 328.
-- Хоть и направление обеих метрик скорости совпадает с гипотезой:
-- медиана времени до первой коммуникации 51.08 ч против 54.67 ч,
-- доля первых контактов в первые 24 часа 33.33% против 31.71%.
-- Однако стотит заметить, что различия есть, но небольшие и их величина скорее находится на уровне шума:
-- 3.59 ч это около 7% от медианы (~52 ч), а 1.62 п.п. при стандартной ошибке разности долей ≈ 6.9 п.п. 
-- Следовательно, данные не позволяют ни подтвердить гипотезу, ни уверенно её отвергнуть, поэтому данных просто недостаточно.

-- итог: нужны еще данные

-- можно попробовать ответить какие: тест разности долей, посмотреть зафиксированный минимальный значимый эффект, либо просто увеличить количесво данных)



