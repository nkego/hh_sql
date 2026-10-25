-- ============================================================
-- Домашнее задание к лекции «Продвинутый SQL»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Коняхин Никита Андреевич


SET search_path TO hh_school;

-- Блок А. Качество и подготовка данных
-- Задание 1 Аудит качества данных

-- 1. Общая структура звонков
SELECT
    COUNT(*) FILTER (WHERE status = 'successful') AS successful_calls,
    COUNT(*) FILTER (WHERE status = 'unsuccessful') AS unsuccessful_calls,
    COUNT(*) FILTER (WHERE status = 'error') AS error_calls,
    COUNT(*) FILTER (WHERE response_id IS NULL) AS calls_without_response_id,
    COUNT(*) FILTER (WHERE status = 'successful' AND response_id IS NULL) AS successful_calls_without_response_id,
    COUNT(*) AS calls_total
FROM hh_school.calls;
-- Вывод: большинство звонков успешные, но есть 8 звонков без response_id, поэтому их нужно отдельно проверить, так как они не связываются напрямую с откликом.


-- 2. Общая структура сообщений
SELECT
    COUNT(*) AS messages_total
FROM hh_school.messages;


-- 3. Звонки без response_id
SELECT
    COUNT(*) AS rows_count,
    STRING_AGG(c.call_id::text, ', ' ORDER BY c.call_id) AS call_ids
FROM hh_school.calls AS c
WHERE c.response_id IS NULL;


-- 4. Звонки без response_id, которые при сопоставлении с откликом по вакансии и кандидату произошли раньше отклика
SELECT
    COUNT(*) AS rows_count,
    STRING_AGG(c.call_id::text, ', ' ORDER BY c.call_id) AS call_ids
FROM hh_school.calls AS c
WHERE c.response_id IS NULL
  AND EXISTS (
        SELECT 1
        FROM hh_school.responses AS r
        WHERE r.vacancy_id = c.vacancy_id
          AND r.resume_id = c.applicant_id
          AND c.call_at < r.created_at
  );


-- 5. Связанные звонки, которые произошли раньше отклика
SELECT
    COUNT(*) AS linked_calls_before_response
FROM hh_school.calls AS c
JOIN hh_school.responses AS r
  ON c.response_id = r.response_id
WHERE c.call_at < r.created_at;
-- Вывод: временная логика связанных звонков корректна.

-- 6. Сообщения, которые отправлены раньше отклика
SELECT
    COUNT(*) AS linked_messages_before_response
FROM hh_school.messages AS m
JOIN hh_school.responses AS r
  ON m.response_id = r.response_id
WHERE m.sent_at < r.created_at;
-- Временная логика сообщений корректна.


-- 7. Несогласованность идентификаторов в звонках относительно отклика и вакансии
SELECT
    COUNT(*) AS call_identifier_mismatches
FROM hh_school.calls AS c
JOIN hh_school.responses AS r
  ON c.response_id = r.response_id
JOIN hh_school.vacancies AS v
  ON r.vacancy_id = v.vacancy_id
WHERE c.response_id IS NOT NULL
  AND (
        c.vacancy_id <> r.vacancy_id
     OR c.employer_id <> v.employer_id
     OR c.applicant_id <> r.resume_id
  );
-- нет расхождений


-- 8. Несогласованность идентификаторов в сообщениях относительно отклика и вакансии
SELECT
    COUNT(*) AS message_identifier_mismatches
FROM hh_school.messages AS m
JOIN hh_school.responses AS r
  ON m.response_id = r.response_id
JOIN hh_school.vacancies AS v
  ON r.vacancy_id = v.vacancy_id
WHERE m.vacancy_id <> r.vacancy_id
   OR m.employer_id <> v.employer_id
   OR m.applicant_id <> r.resume_id;
-- нет расхождений


-- 9. Противоречие между статусом звонка и длительностью
SELECT
    COUNT(*) AS status_duration_conflicts
FROM hh_school.calls
WHERE (status = 'successful' AND call_duration IS NULL)
   OR (status IN ('unsuccessful', 'error') AND call_duration IS NOT NULL);
-- Вывод: длительность звонков согласована со статусом.


-- 10. Противоречие между статусом звонка и тегами
SELECT
    COUNT(*) AS status_tag_conflicts
FROM hh_school.calls
WHERE (status = 'successful' AND NOT 'connected' = ANY(call_tags))
   OR (status = 'unsuccessful' AND 'connected' = ANY(call_tags))
   OR (status = 'error' AND NOT 'technical_error' = ANY(call_tags));
-- Вывод: статус звонков не противоречит тегам.


-- 11. Противоречие между ролью инициатора звонка и направлением звонка
SELECT
    COUNT(*) AS caller_role_direction_conflicts
FROM hh_school.calls
WHERE (caller_role = 'employer' AND NOT 'outbound' = ANY(call_tags))
   OR (caller_role = 'applicant' AND NOT 'inbound' = ANY(call_tags));
-- Вывод: роль инициатора звонка согласована с направлением звонка.


-- 12. Звонки со статусом error
SELECT
    c.call_id,
    c.status,
    c.call_duration,
    c.call_tags
FROM hh_school.calls AS c
WHERE c.status = 'error';
-- Вывод: найден один звонок с технической ошибкой.


-- 13. Фактические ключи в message_meta и их длина
SELECT
    kv.key_name AS actual_key,
    LENGTH(kv.key_name) AS key_length,
    COUNT(*) AS rows_count
FROM hh_school.messages AS m
CROSS JOIN LATERAL jsonb_each_text(m.message_meta) AS kv(key_name, value_text)
GROUP BY
    kv.key_name,
    LENGTH(kv.key_name)
ORDER BY
    kv.key_name;
-- Вывод: все ключи присутствуют во всех сообщениях и не содержат лишних пробелов в конце.


-- 14. Извлечение канала по ключу 'channel'
SELECT
    COUNT(*) AS total_messages,
    COUNT(*) FILTER (WHERE m.message_meta ->> 'channel' IS NULL) AS channel_null_count,
    COUNT(DISTINCT m.message_meta ->> 'channel') AS distinct_channel_values
FROM hh_school.messages AS m;
-- Вывод: пропусков нет, значения канала извлекаются корректно.


-- 15. Проверка наличия ключа с пробелом в конце
SELECT
    COUNT(*) AS channel_with_space_null_count
FROM hh_school.messages
WHERE message_meta ->> 'channel ' IS NULL;


-- 16. Проверка значений канала на пробелы в конце и распределение каналов
SELECT
    m.message_meta ->> 'channel'  AS channel_value,
    LENGTH(m.message_meta ->> 'channel') AS value_length,
    COUNT(*) AS rows_count
FROM hh_school.messages AS m
GROUP BY
    m.message_meta ->> 'channel',
    LENGTH(m.message_meta ->> 'channel')
ORDER BY
    rows_count DESC;
-- Вывод: значения канала не содержат пробелов в конце.
-- Дополнительная очистка значений не требуется.


-- 17. Статистика по длительности успешных звонков
WITH successful_calls AS (
    SELECT
        c.call_id,
        c.call_duration
    FROM hh_school.calls AS c
    WHERE c.status = 'successful'
),
p99 AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY sc.call_duration) AS p99_duration
    FROM successful_calls AS sc
)
SELECT
    ROUND((SELECT AVG(sc.call_duration) FROM successful_calls AS sc)::numeric, 2)
        AS avg_duration,

    ROUND((
        SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sc.call_duration)
        FROM successful_calls AS sc
    )::numeric, 2)
        AS median_duration,

    ROUND(p.p99_duration::numeric, 2) AS p99_duration,

    (
        SELECT COUNT(*)
        FROM successful_calls AS sc
        WHERE sc.call_duration > p.p99_duration
    ) AS calls_above_p99,

    ROUND((
        SELECT AVG(sc.call_duration)
        FROM successful_calls AS sc
        WHERE sc.call_duration <= p.p99_duration
    )::numeric, 2) AS avg_duration_excluding_above_p99
FROM p99 AS p;
-- Вывод: типичная длительность успешного звонка ближе к медиане (438 секунд)
-- Среднее значение немного выше из-за редких длинных звонков.
-- После исключения значений выше 99 перцентиля среднее снижается до 462.49 секунд.


-- 18. Успешные звонки, длительность которых выше 99 перцентиля
WITH successful_calls AS (
    SELECT
        c.call_id,
        c.call_duration
    FROM hh_school.calls AS c
    WHERE c.status = 'successful'
),
p99 AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY sc.call_duration) AS p99_duration
    FROM successful_calls AS sc
)
SELECT
    sc.call_id,
    sc.call_duration
FROM successful_calls AS sc
CROSS JOIN p99 AS p
WHERE sc.call_duration > p.p99_duration
ORDER BY sc.call_duration DESC;
-- Вывод: выше 99 перцентиля находятся два успешных звонка.
-- Они формально валидны: статус successful, положительная длительность,
-- есть тег connected. это скорее допустимые выбросы, а не ошибки.


-- Итоговый вывод

-- Найденные проблемы:
-- 1. Звонки без response_id: 8 шт, из них 3 успешных.
--    При сопоставлении по вакансии и кандидату все 8 произошли раньше создания отклика.
--
-- 2. Звонок со статусом error: 1 шт.
--
-- 3. Значения длительности выше 99 перцентиля: 2 шт.
--    формально валидные успешные звонки, не ошибки.

-- Контрольные значения по длительности успешных звонков:
--   средняя длительность: 467.28 сек.
--   медиана: 438.00 сек.
--   99-й перцентиль: 890.40 сек.
--   количество звонков выше 99 перцентиля: 2
--   средняя после исключения выше 99 перцентиля: 462.49 сек.

-- Аналитическое решение по выбросам:
-- Значения выше 99 перцентиля считаю допустимыми:
-- оба звонка имеют статус successful, положительную длительность и тег connected.

-- При расчёте типичной длительности буду использовать медиану как устойчивую к выбросам метрику. 


-- Блок Б. История коммуникаций
-- Задание 2 Единый слой коммуникаций

WITH messages_7d AS (
    SELECT
        r.response_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM hh_school.messages AS m
    JOIN hh_school.responses AS r
      ON r.response_id = m.response_id
    WHERE m.sender_role = 'employer'
      AND m.sent_at >= r.created_at
      AND m.sent_at <  r.created_at + INTERVAL '7 day'
),

calls_7d AS (
    SELECT
        r.response_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM hh_school.calls AS c
    JOIN hh_school.responses AS r
      ON r.response_id = c.response_id
    WHERE c.caller_role = 'employer'
      AND c.call_at >= r.created_at
      AND c.call_at <  r.created_at + INTERVAL '7 day'
),

events AS (
    SELECT response_id, event_id, event_at, event_type
    FROM messages_7d
    UNION ALL
    SELECT response_id, event_id, event_at, event_type
    FROM calls_7d
)

SELECT
    COUNT(*) AS total_events,
    COUNT(DISTINCT response_id) AS responses_with_communication,
    COUNT(*) FILTER (WHERE event_type = 'call') AS calls_count,
    COUNT(*) FILTER (WHERE event_type = 'message') AS messages_count
FROM events;

-- total_events = 1096
-- responses_with_communication = 382
-- calls_count = 108
-- messages_count = 988



-- Задание 3 Таймлайн коммуникаций и витрина отклика
-- Шаг 1. Слой уровня события

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

messages_7d AS (
    SELECT
        rs.response_id,
        rs.employer_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM hh_school.messages AS m
    JOIN response_scope AS rs
      ON rs.response_id = m.response_id
    WHERE m.sender_role = 'employer'
      AND m.sent_at >= rs.response_created_at
      AND m.sent_at <  rs.response_created_at + INTERVAL '7 day'
),

calls_7d AS (
    SELECT
        rs.response_id,
        rs.employer_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM hh_school.calls AS c
    JOIN response_scope AS rs
      ON rs.response_id = c.response_id
    WHERE c.caller_role = 'employer'
      AND c.response_id IS NOT NULL
      AND c.call_at >= rs.response_created_at
      AND c.call_at <  rs.response_created_at + INTERVAL '7 day'
),

events AS (
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM messages_7d
    UNION ALL
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM calls_7d
),

event_timeline AS (
    SELECT
        e.response_id,
        e.employer_id,
        e.event_id,
        e.event_at,
        e.event_type,

        ROW_NUMBER() OVER (
            PARTITION BY e.response_id
            ORDER BY e.event_at, e.event_type, e.event_id
        ) AS event_number,

        LAG(e.event_at) OVER (
            PARTITION BY e.response_id
            ORDER BY e.event_at, e.event_type, e.event_id
        ) AS previous_event_at,

        LEAD(e.event_type) OVER (
            PARTITION BY e.response_id
            ORDER BY e.event_at, e.event_type, e.event_id
        ) AS next_event_type,

        COUNT(*) OVER (
            PARTITION BY e.response_id
            ORDER BY e.event_at, e.event_type, e.event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS events_so_far,

        FIRST_VALUE(e.event_type) OVER (
            PARTITION BY e.response_id
            ORDER BY e.event_at, e.event_type, e.event_id
        ) AS first_event_type,

        LAST_VALUE(e.event_type) OVER (
            PARTITION BY e.response_id
            ORDER BY e.event_at, e.event_type, e.event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS last_event_type
    FROM events AS e
)

SELECT
    response_id,
    employer_id,
    event_id,
    event_at,
    event_type,
    event_number,
    previous_event_at,
    next_event_type,
    events_so_far,
    first_event_type,
    last_event_type
FROM event_timeline
ORDER BY
    response_id,
    event_number;

-- Вывод: гранулярность сохранена одна строка по-прежнему равна одной коммуникации.



-- Шаг 2. Витрина уровня отклика

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

messages_7d AS (
    SELECT
        rs.response_id,
        rs.employer_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM hh_school.messages AS m
    JOIN response_scope AS rs
      ON rs.response_id = m.response_id
    WHERE m.sender_role = 'employer'
      AND m.sent_at >= rs.response_created_at
      AND m.sent_at <  rs.response_created_at + INTERVAL '7 day'
),

calls_7d AS (
    SELECT
        rs.response_id,
        rs.employer_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM hh_school.calls AS c
    JOIN response_scope AS rs
      ON rs.response_id = c.response_id
    WHERE c.caller_role = 'employer'
      AND c.response_id IS NOT NULL
      AND c.call_at >= rs.response_created_at
      AND c.call_at <  rs.response_created_at + INTERVAL '7 day'
),

events AS (
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM messages_7d
    UNION ALL
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM calls_7d
),

event_timeline AS (
    SELECT
        e.response_id,
        e.event_id,
        e.event_at,
        e.event_type,
        ROW_NUMBER() OVER (
            PARTITION BY e.response_id
            ORDER BY e.event_at, e.event_type, e.event_id
        ) AS event_number,
        LAG(e.event_at) OVER (
            PARTITION BY e.response_id
            ORDER BY e.event_at, e.event_type, e.event_id
        ) AS previous_event_at,
        LAST_VALUE(e.event_type) OVER (
            PARTITION BY e.response_id
            ORDER BY e.event_at, e.event_type, e.event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS last_event_type
    FROM events AS e
),

event_stats AS (
    SELECT
        t.response_id,
        COUNT(*) AS communication_count,
        COUNT(*) FILTER (WHERE t.event_type = 'call') AS call_count,
        COUNT(*) FILTER (WHERE t.event_type = 'message') AS message_count,
        MIN(t.event_at) AS first_communication_at,
        MAX(t.event_type) FILTER (WHERE t.event_number = 1) AS first_event_type,
        MAX(t.event_type) FILTER (WHERE t.event_number = 2) AS second_event_type,
        MAX(t.last_event_type) AS last_event_type,
        ROUND(MAX(
            EXTRACT(EPOCH FROM (t.event_at - t.previous_event_at)) / 3600.0
        )::numeric, 2) AS max_gap_hours
    FROM event_timeline AS t
    GROUP BY t.response_id
),

response_mart AS (
    SELECT
        rs.response_id,
        rs.employer_id,
        rs.professional_role,
        rs.response_status,
        COALESCE(es.communication_count, 0) AS communication_count,
        COALESCE(es.call_count, 0) AS call_count,
        COALESCE(es.message_count, 0) AS message_count,
        es.first_communication_at,
        es.first_event_type,
        es.second_event_type,
        es.last_event_type,
        ROUND((
            EXTRACT(EPOCH FROM (es.first_communication_at - rs.response_created_at)) / 3600.0
        )::numeric, 2) AS hours_to_first_communication,
        es.max_gap_hours
    FROM response_scope AS rs
    LEFT JOIN event_stats AS es
      ON es.response_id = rs.response_id
)

SELECT
    response_id,
    employer_id,
    professional_role,
    response_status,
    communication_count,
    call_count,
    message_count,
    first_communication_at,
    first_event_type,
    second_event_type,
    last_event_type,
    hours_to_first_communication,
    max_gap_hours
FROM response_mart
ORDER BY response_id;
-- Вывод: витрина сохраняет все отклики


-- Итоговые контрольные значения по витрине

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

messages_7d AS (
    SELECT
        rs.response_id,
        rs.employer_id,
        m.message_id::text AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM hh_school.messages AS m
    JOIN response_scope AS rs
      ON rs.response_id = m.response_id
    WHERE m.sender_role = 'employer'
      AND m.sent_at >= rs.response_created_at
      AND m.sent_at <  rs.response_created_at + INTERVAL '7 day'
),

calls_7d AS (
    SELECT
        rs.response_id,
        rs.employer_id,
        c.call_id::text AS event_id,
        c.call_at AS event_at,
        'call' AS event_type
    FROM hh_school.calls AS c
    JOIN response_scope AS rs
      ON rs.response_id = c.response_id
    WHERE c.caller_role = 'employer'
      AND c.response_id IS NOT NULL
      AND c.call_at >= rs.response_created_at
      AND c.call_at <  rs.response_created_at + INTERVAL '7 day'
),

events AS (
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM messages_7d
    UNION ALL
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM calls_7d
),

event_timeline AS (
    SELECT
        e.response_id,
        e.event_at,
        e.event_type,
        ROW_NUMBER() OVER (
            PARTITION BY e.response_id
            ORDER BY e.event_at, e.event_type, e.event_id
        ) AS event_number
    FROM events AS e
),

event_stats AS (
    SELECT
        t.response_id,
        COUNT(*) AS communication_count,
        MAX(t.event_type) FILTER (WHERE t.event_number = 1) AS first_event_type
    FROM event_timeline AS t
    GROUP BY t.response_id
),

response_mart AS (
    SELECT
        rs.response_id,
        COALESCE(es.communication_count, 0) AS communication_count,
        es.first_event_type
    FROM response_scope AS rs
    LEFT JOIN event_stats AS es
      ON es.response_id = rs.response_id
)

SELECT
    COUNT(*) AS mart_rows,
    COUNT(*) FILTER (WHERE communication_count > 0) AS responses_with_communication,
    COUNT(*) FILTER (WHERE communication_count = 0) AS responses_without_communication,
    COUNT(*) FILTER (WHERE first_event_type = 'message') AS first_communication_message,
    COUNT(*) FILTER (WHERE first_event_type = 'call') AS first_communication_call
FROM response_mart;

-- Вывод:
-- mart_rows = 628
-- responses_with_communication = 382
-- responses_without_communication = 246
-- first_communication_message = 314
-- first_communication_call = 68
-- Проверка: first_communication_message + first_communication_call = 382








-- Блок В. Сравнение работодателей
-- 4. Рейтинг работодателей внутри направления

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

messages_7d AS (
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
),

calls_7d AS (
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

events AS (
    SELECT response_id, event_id, event_at, event_type
    FROM messages_7d
    UNION ALL
    SELECT response_id, event_id, event_at, event_type
    FROM calls_7d
),

response_mart AS (
    SELECT
        rs.response_id,
        rs.employer_id,
        rs.professional_role,
        rs.response_status,
        MIN(e.event_at) AS first_communication_at,
        EXTRACT(EPOCH FROM (MIN(e.event_at) - rs.response_created_at)) / 3600.0
            AS hours_to_first_communication
    FROM response_scope AS rs
    LEFT JOIN events AS e
      ON e.response_id = rs.response_id
    GROUP BY
        rs.response_id,
        rs.employer_id,
        rs.professional_role,
        rs.response_status,
        rs.response_created_at
),

employer_stats AS (
    SELECT
        professional_role,
        employer_id,
        COUNT(*) AS response_count,
        COUNT(*) FILTER (WHERE first_communication_at IS NOT NULL) AS responses_with_communication,
        ROUND(
            100.0 * COUNT(*) FILTER (WHERE first_communication_at IS NOT NULL) / COUNT(*),
            2
        ) AS processed_share_pct,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY hours_to_first_communication
        )::numeric, 2) AS median_hours_to_first,
        ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (
            ORDER BY hours_to_first_communication
        )::numeric, 2) AS p90_hours_to_first,
        ROUND(
            100.0 * COUNT(*) FILTER (WHERE response_status = 'invited') / COUNT(*),
            2
        ) AS invite_conversion_pct
    FROM response_mart
    GROUP BY
        professional_role,
        employer_id
    HAVING COUNT(*) >= 8   
),

ranked AS (
    SELECT
        s.*,
        DENSE_RANK() OVER (
            PARTITION BY s.professional_role
            ORDER BY
                s.processed_share_pct DESC,
                s.median_hours_to_first ASC NULLS LAST
        ) AS place
    FROM employer_stats AS s
)

SELECT
    professional_role,
    place,
    employer_id,
    response_count,
    responses_with_communication,
    processed_share_pct,
    median_hours_to_first,
    p90_hours_to_first,
    invite_conversion_pct
FROM ranked
WHERE place <= 2  
ORDER BY
    professional_role,
    place,
    employer_id;


-- Итоговые 1 и 2 места по направлениям:
-- Аналитик данных      | место 1 | employer_id = 109 
-- Аналитик данных      | место 2 | employer_id = 103
-- Дата-инженер         | место 1 | employer_id = 106
-- Дата-инженер         | место 2 | employer_id = 101
-- Продуктовый аналитик | место 1 | employer_id = 103
-- Продуктовый аналитик | место 2 | employer_id = 102
-- Разработчик          | место 1 | employer_id = 112
-- Разработчик          | место 2 | employer_id = 104
-- Тестировщик          | место 1 | employer_id = 107
-- Тестировщик          | место 2 | employer_id = 108

-- Наблюдения
-- Самая высокая доля обработанных откликов у работодателя 109 среди аналитиков
-- Работодатель 107 сочетает высокую долю с максимальной конверсией в приглашение
-- Работодатель 104 отвечает быстрее всех среди разработчиков, но по доле обработанных уступает 112 и занимает 2 место.

-- Задание 5 Скорость ответа работодателя в переписке

WITH messages_7d AS (      
    SELECT
        m.message_id,
        m.response_id,
        m.employer_id,
        m.sender_role,
        m.sent_at
    FROM messages AS m
    JOIN responses AS r
      ON r.response_id = m.response_id         
    WHERE m.sent_at >= r.created_at
      AND m.sent_at <  r.created_at + INTERVAL '7 day'
),
timeline AS (    
    SELECT
        message_id,
        response_id,
        employer_id,
        sender_role,
        sent_at,
        LAG(sender_role) OVER w AS prev_sender_role,
        LAG(sent_at)     OVER w AS prev_sent_at
    FROM messages_7d
    WINDOW w AS (PARTITION BY response_id
                 ORDER BY sent_at, sender_role, message_id) 
),
employer_replies AS (
    SELECT
        employer_id,
        EXTRACT(EPOCH FROM (sent_at - prev_sent_at)) / 3600.0 AS reply_hours
    FROM timeline
    WHERE sender_role      = 'employer'
      AND prev_sender_role = 'applicant'  
)
SELECT
    employer_id,
    COUNT(*)                                          AS reply_count,
    ROUND(AVG(reply_hours)::numeric, 2)               AS avg_reply_hours,
    ROUND(PERCENTILE_CONT(0.5)
          WITHIN GROUP (ORDER BY reply_hours)::numeric, 2) AS median_reply_hours,
    ROUND(PERCENTILE_CONT(0.9)
          WITHIN GROUP (ORDER BY reply_hours)::numeric, 2) AS p90_reply_hours
FROM employer_replies
GROUP BY employer_id
ORDER BY median_reply_hours ASC;


-- итоговый запрос

WITH messages_7d AS (
    SELECT m.message_id, m.response_id, m.employer_id, m.sender_role, m.sent_at
    FROM messages AS m
    JOIN responses AS r ON r.response_id = m.response_id
    WHERE m.sent_at >= r.created_at
      AND m.sent_at <  r.created_at + INTERVAL '7 day'
),
timeline AS (
    SELECT message_id, employer_id, sender_role, sent_at,
           LAG(sender_role) OVER w AS prev_sender_role,
           LAG(sent_at)     OVER w AS prev_sent_at
    FROM messages_7d
    WINDOW w AS (PARTITION BY response_id ORDER BY sent_at, sender_role, message_id)
),
employer_replies AS (
    SELECT employer_id,
           EXTRACT(EPOCH FROM (sent_at - prev_sent_at)) / 3600.0 AS reply_hours
    FROM timeline
    WHERE sender_role = 'employer' AND prev_sender_role = 'applicant'
),
stats AS (
    SELECT employer_id,
           COUNT(*) AS reply_count,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY reply_hours) AS median_reply_hours
    FROM employer_replies
    GROUP BY employer_id
)
SELECT
    (SELECT SUM(reply_count) FROM stats)   AS total_replies,
    employer_id                            AS fastest_employer_id,
    ROUND(median_reply_hours::numeric, 2)  AS fastest_median_hours
FROM stats
ORDER BY median_reply_hours ASC
LIMIT 1;

-- Общее количество найденных ответов = 749
-- employer_id с мин медианой = 107
-- Значение медианы = 3.93





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
--   web:        messages_count = 628
--   mobile_app: messages_count = 360
-- Проверка: 628 + 360 = 988 — сходится с числом сообщений работодателя


-- Непрочитанные сообщения:
--   mobile_app: unread_count = 36, unread_share_pct = 10.00
--   web:        unread_count = 52, unread_share_pct = 8.28

-- Сообщения хотя бы с одним вложением:
--   mobile_app: with_attachment_count = 14, attachment_share_pct = 3.89
--   web:        with_attachment_count = 25, attachment_share_pct = 3.98

-- Наблюдения: web это основной канал переписки работодателя
-- Доля непрочитанных сообщений на mobile_app немного выше, а доля сообщений с вложениями на обоих каналах близка (3.89% и 3.98%).





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


-- Вывод по H1: 
-- invited (N = 92): median_communications = 2, avg = 1.63, multichannel_share = 14.81%.
-- other (N = 536):  median_communications = 3, avg = 1.76, multichannel_share = 17.38%.
-- По откликам с приглашением работодатель коммуницирует менее интенсивно и реже использует оба канала. Различия заметные (медиана 2 против 3, мультиканальность 14.81% против 17.38%). 
-- итого: гипотеза не подтвердилась ((
--
-- Вывод по H2:
-- invited: median_hours_to_first = 51.08 ч, first_within_24h_share = 33.33%, first_contact_call_share = 20.37%.
-- other:   median_hours_to_first = 54.67 ч, first_within_24h_share = 31.71%, first_contact_call_share = 17.38%.
-- По откликам с приглашением работодатель выходит на связь немного быстрее (медиана на 3.59 ч ниже), чуть чаще в первые 24 ч (на 1.62 п.п.) и чуть чаще начинает со звонка (на 2.99 п.п.).
-- Различия есть, но небольшие, связь со скоростью первого контакта есть, но она не является главным отличием invited от other.
-- итого: гипотеза подтвердилась (сомнительно, но окей)



-- 8. Итог исследования
--
-- 1. В первые 7 дней после отклика работодатель вышел на связь по 382 из 628 откликов (60.8%), то есть почти четыре из десяти откликов остаются без какой-либо коммуникации (задание 3).
-- 2. Единый слой коммуникаций состоит из 1096 событий: 988 сообщений и 108 звонков работодателя (задания 2 и 6.1); 
--    основной канал переписки web (628 сообщений, около 64%), mobile_app дополнительный (360) (задание 6.2).
-- 3. Первый контакт почти всегда происходит сообщением: 314 откликов (82.2%) против 68 (17.8%), начавшихся со звонка (задание 3).
-- 4. Работодатели внутри направлений различаются сильно: 
--    среди аналитиков данных лидер обрабатывает 89.47% откликов (employer 109), а работодатель с наибольшим объёмом (101, 115 откликов) в топ2 направления не попал; 
--    среди тестировщиков employer 107 сочетает обработку 88.24% откликов с максимальной конверсией в приглашение 41.18% (задание 4).
-- 5. Успешные звонки длятся медианно 438 секунд; два значения выше 99го перцентиля (892 и 899 секунд) признаны допустимыми выбросами, а не ошибками (задание 1).
-- 6. По откликам с приглашением (N = 92) работодатель коммуницирует менее интенсивно, чем по остальным (N = 536): 
--    медиана числа коммуникаций 2 против 3, доля мультиканальных откликов 14.81% против 17.38% (задание 7, H1 не подтверждается).
-- 7. При этом по приглашённым откликам первый контакт происходит немного быстрее:
--    медиана 51.08 ч против 54.67 ч, доля контактов за 24 ч 33.33% против 31.71%, и чуть чаще первым каналом оказывается звонок (20.37% против 17.38%) (задание 7, H2 подтверждается слабо).
-- 8. В целом коммуникация после отклика это «message-first» процесс умеренной интенсивности: 
--    связь с приглашением наблюдается по скорости первого контакта, а не по числу коммуникаций, это наблюдаемая связь, а не причинноследственная, поскольку приглашение зависит и от качества кандидата, которого нет в наших данных.
-- 9. Ограничения: 
--    окно 7 дней обрезает поздние коммуникации; 8 звонков без response_id (700244–700251) исключены из анализа; 
--    статус отклика зафиксирован на момент выгрузки и мог измениться позже; группы invited/other несбалансированы по размеру (92 против 536), поэтому небольшие различия в долях могут быть статистически незначимыми.
-- 10. Следующий исследовательский вопрос: 
--     влияет ли скорость ответа работодателя на первое сообщение кандидата (в течение 24 часов) на вероятность приглашения
--     при контроле направления и объёма работодателя и для этого запросить данные о качестве резюме кандидатов и срочности вакансий.